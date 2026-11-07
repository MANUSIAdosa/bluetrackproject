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
  const ActionsPage({
    super.key,
    this.repository,
    this.participationStore,
    this.now,
  });

  /// Test/demo override; the router keeps constructing `const ActionsPage()`.
  final ActionRepository? repository;

  /// Test/demo override for joined-action state.
  final ActionParticipationStore? participationStore;

  /// Test/clock seam for activity status; defaults to [DateTime.now].
  final DateTime Function()? now;

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

  DateTime get _now => (widget.now ?? DateTime.now)();

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
      return _list(
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
    return _list(
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

    return _list(
      key: const ValueKey('actions.joinedList'),
      itemCount: joined.length,
      itemBuilder: (context, index) => _card(joined[index]),
    );
  }

  Widget _card(ActionItem item) {
    return ActionCard(
      key: ValueKey('actionCard.${item.id}'),
      item: item,
      registered: _joinedIds.contains(item.id),
      now: _now,
      onTap: () async {
        await context.push(Routes.actionDetailUrl(item.id));
        if (!mounted) return;
        await _refreshJoined();
      },
    );
  }

  /// Responsive list: one column on phones, two from 600dp — the same
  /// breakpoint Explore uses. Rows hold two [Expanded] cards inside an
  /// [IntrinsicHeight] so both cards in a row share the taller content height
  /// and their action hints line up. No cell extent is computed by hand.
  Widget _list({
    required Key key,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    final twoColumns = MediaQuery.sizeOf(context).width >= 600;
    const padding = 12.0;
    const gap = 12.0;
    final rowCount = twoColumns ? (itemCount + 1) ~/ 2 : itemCount;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.separated(
          key: key,
          padding: const EdgeInsets.all(padding),
          itemCount: rowCount,
          separatorBuilder: (_, _) => const SizedBox(height: gap),
          itemBuilder: (context, row) {
            if (!twoColumns) {
              return IntrinsicHeight(child: itemBuilder(context, row));
            }

            final first = row * 2;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: itemBuilder(context, first)),
                  const SizedBox(width: gap),
                  Expanded(
                    child: first + 1 < itemCount
                        ? itemBuilder(context, first + 1)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
