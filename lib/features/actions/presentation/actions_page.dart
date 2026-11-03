import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../data/action_participation_store.dart';
import '../data/action_repository.dart';
import '../domain/action_item.dart';
import 'widgets/action_card.dart';
import 'widgets/action_card_skeleton.dart';

/// Action Agenda (Aksi).
///
/// Two sub-tabs share the same cards: the agenda of available actions and the
/// actions the user has registered for. Search, filters and map view still
/// belong to later parts.
class ActionsPage extends StatefulWidget {
  const ActionsPage({super.key, this.repository, this.participationStore});

  /// Test/demo override; the router keeps constructing `const ActionsPage()`.
  final ActionRepository? repository;

  /// Test/demo override for joined-action state.
  final ActionParticipationStore? participationStore;

  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends State<ActionsPage>
    with SingleTickerProviderStateMixin {
  late final ActionRepository _repository =
      widget.repository ?? const MockActionRepository();
  late final ActionParticipationStore _participationStore =
      widget.participationStore ?? const PrefsActionParticipationStore();
  late final TabController _tabController;

  List<ActionItem>? _items;
  Set<String> _joinedIds = const {};
  bool _loading = true;
  bool _error = false;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabIndex == _tabController.index) return;
    _tabIndex = _tabController.index;
    if (_tabIndex == 1) _refreshJoined();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final items = await _repository.getActions();

      // A local storage failure must not hide the agenda; the joined tab just
      // stays empty until the next successful read.
      Set<String> joined;
      try {
        joined = await _participationStore.registeredIds();
      } catch (_) {
        joined = const {};
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _joinedIds = joined;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  /// Re-reads local participation after a detail visit or a tab switch so a
  /// newly registered action appears without restarting the page.
  Future<void> _refreshJoined() async {
    Set<String> joined;
    try {
      joined = await _participationStore.registeredIds();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _joinedIds = joined);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('nav.aksi')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              key: const ValueKey('actions.tab.agenda'),
              text: context.tr('action.tab.agenda'),
            ),
            Tab(
              key: const ValueKey('actions.tab.joined'),
              text: context.tr('action.tab.joined'),
            ),
          ],
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return _grid(
        key: const ValueKey('actions.loading'),
        itemCount: 6,
        itemBuilder: (_, _) => const ActionCardSkeleton(),
      );
    }

    if (_error) {
      return ErrorState(
        message: context.tr('action.unavailable'),
        onRetry: _load,
      );
    }

    final items = _items ?? const <ActionItem>[];
    return TabBarView(
      controller: _tabController,
      children: [
        _agendaTab(context, items),
        _joinedTab(context, items),
      ],
    );
  }

  Widget _agendaTab(BuildContext context, List<ActionItem> items) {
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy_outlined,
        message: context.tr('action.empty'),
      );
    }
    return _grid(
      key: const ValueKey('actions.list'),
      itemCount: items.length,
      itemBuilder: (context, index) => _card(items[index]),
    );
  }

  Widget _joinedTab(BuildContext context, List<ActionItem> items) {
    final joined = items
        .where((item) => _joinedIds.contains(item.id))
        .toList(growable: false);

    if (joined.isEmpty) {
      return EmptyState(
        key: const ValueKey('actions.joinedEmpty'),
        icon: Icons.event_available_outlined,
        message: context.tr('action.joined.empty'),
        actionLabel: context.tr('action.joined.viewAgenda'),
        onAction: () => _tabController.animateTo(0),
      );
    }

    return _grid(
      key: const ValueKey('actions.joinedList'),
      itemCount: joined.length,
      itemBuilder: (context, index) => _card(joined[index]),
    );
  }

  Widget _card(ActionItem item) {
    return ActionCard(
      key: ValueKey('actionCard.${item.id}'),
      item: item,
      onTap: () async {
        await context.push(Routes.actionDetailUrl(item.id));
        if (!mounted) return;
        await _refreshJoined();
      },
    );
  }

  /// Two equal columns with one shared gap. The cell extent is derived from
  /// the card's own line heights so compact cards stay aligned at every text
  /// scale instead of relying on a brittle fixed aspect ratio.
  Widget _grid({
    required Key key,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const padding = 12.0;
            const gap = 12.0;
            final cardWidth =
                (constraints.maxWidth - padding * 2 - gap) / 2;

            return GridView.builder(
              key: key,
              padding: const EdgeInsets.all(padding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
                mainAxisExtent: ActionCard.gridExtentFor(context, cardWidth),
              ),
              itemCount: itemCount,
              itemBuilder: itemBuilder,
            );
          },
        ),
      ),
    );
  }
}
