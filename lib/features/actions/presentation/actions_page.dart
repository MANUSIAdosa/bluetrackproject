import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../data/action_repository.dart';
import '../domain/action_item.dart';
import 'widgets/action_card.dart';
import 'widgets/action_card_skeleton.dart';

/// Action Agenda (Aksi) — the grid of conservation actions users can join.
///
/// Scope of this part: the agenda cards only. Search, filters, map view and
/// joined actions arrive in later parts; this page deliberately has no
/// controls for them yet.
class ActionsPage extends StatefulWidget {
  const ActionsPage({super.key, this.repository});

  /// Test/demo override; the router keeps constructing `const ActionsPage()`.
  final ActionRepository? repository;

  @override
  State<ActionsPage> createState() => _ActionsPageState();
}

class _ActionsPageState extends State<ActionsPage> {
  late final ActionRepository _repository =
      widget.repository ?? const MockActionRepository();

  List<ActionItem>? _items;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final items = await _repository.getActions();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.aksi'))),
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
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy_outlined,
        message: context.tr('action.empty'),
      );
    }

    return _grid(
      key: const ValueKey('actions.list'),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ActionCard(
          key: ValueKey('actionCard.${item.id}'),
          item: item,
          onTap: () => context.push(Routes.actionDetailUrl(item.id)),
        );
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
