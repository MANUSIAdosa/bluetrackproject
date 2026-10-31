import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/login_prompt_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../application/notification_providers.dart';
import '../domain/app_notification.dart';

/// P13 — `/notifications`.
///
/// Reads the notification list through [notificationListProvider] (Riverpod;
/// the same source the shell badge derives its count from). Items are grouped
/// by recency — Hari ini / Minggu ini / Lebih lama — always computed against
/// the current time, never a stored category. Tapping an item marks it read
/// first, then opens its registered target route; dismissing one (swipe)
/// removes it, and both flows update the page, list and badge through the same
/// provider state.
///
/// Login is deliberately non-blocking: while the stub session state says the
/// user is signed off, a prompt card sits above the list and the mock data
/// stays visible, so nothing in this page can lock the user out.
/// TODO(P13-part-6): [AuthController] is a stub sign-in flag held over from
/// P02 — swap it for the real session source when authentication lands in
/// weeks 12–13. It is read here only; the notification repository stays
/// login-agnostic.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('p13.title')),
        actions: [
          TextButton(
            onPressed: unreadCount > 0
                ? () =>
                    ref.read(notificationListProvider.notifier).markAllAsRead()
                : null,
            child: Text(context.tr('p13.markAllRead')),
          ),
        ],
      ),
      body: ref.watch(notificationListProvider).when(
            loading: _buildSkeleton,
            error: (_, _) => _buildError(context, ref),
            data: (items) => ListenableBuilder(
              listenable: AuthController.instance,
              builder: (context, _) => _buildList(context, ref, items),
            ),
          ),
    );
  }

  // --- UI states -----------------------------------------------------------

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, _) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: _SkeletonRow(),
      ),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref) {
    return EmptyState(
      icon: Icons.error_outline,
      message: context.tr('p13.errorBody'),
      actionLabel: context.tr('p13.retry'),
      onAction: () => ref.invalidate(notificationListProvider),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> items,
  ) {
    return Column(
      children: [
        if (!AuthController.instance.signedIn)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: LoginPromptCard(
              returnLocation: Routes.notifications,
              title: context.tr('p13.loginPrompt.title'),
              body: context.tr('p13.loginPrompt.body'),
            ),
          ),
        Expanded(
          child: _groups(context, ref, items),
        ),
      ],
    );
  }

  // --- List rendering ------------------------------------------------------

  /// The three recency groups, each with a header, plus the empty state when
  /// nothing remains (for example after every item has been deleted).
  Widget _groups(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> items,
  ) {
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).languageCode;

    if (items.isEmpty) {
      return EmptyState(message: context.tr('p13.empty'));
    }

    final widgets = <Widget>[];
    for (final tier in NotificationTimeTier.values) {
      final tierItems = items
          .where((item) => Formatters.timeTier(item.time, now: now) == tier)
          .toList();
      if (tierItems.isEmpty) continue;

      widgets.add(_GroupHeader(label: _groupLabel(context, tier)));
      for (final item in tierItems) {
        widgets.add(
          _NotificationTile(
            notification: item,
            timeLabel: Formatters.notificationTime(
              item.time,
              locale,
              now: now,
            ),
            onOpen: () => _openItem(context, ref, item),
            onDismissed: () => _deleteItem(ref, item),
          ),
        );
      }
    }
    return ListView(children: widgets);
  }

  String _groupLabel(BuildContext context, NotificationTimeTier tier) =>
      switch (tier) {
        NotificationTimeTier.today => context.tr('p13.group.today'),
        NotificationTimeTier.thisWeek => context.tr('p13.group.thisWeek'),
        NotificationTimeTier.older => context.tr('p13.group.older'),
      };

  // --- Interactions --------------------------------------------------------

  /// Mark read first, then navigate — one tap can never re-show the blue dot.
  void _openItem(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
  ) {
    ref.read(notificationListProvider.notifier).markAsRead(item.id);
    _openTarget(context, item.route);
  }

  void _deleteItem(WidgetRef ref, AppNotification item) {
    ref.read(notificationListProvider.notifier).delete(item.id);
  }

  /// Registered routes push directly. Anything the mock points at that is not
  /// (or no longer) registered falls back to a localized message instead of
  /// the router's raw "page not found" screen.
  void _openTarget(BuildContext context, String route) {
    if (!Routes.isKnown(route)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.tr('p13.targetUnavailable'))),
        );
      return;
    }
    context.push(route);
  }
}

/// Loading placeholder rows, mirroring the tile layout they replace.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Skeleton(width: 44, height: 44, radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: double.infinity, height: 14),
              const SizedBox(height: 8),
              Skeleton(width: double.infinity, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.inactiveTab,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.timeLabel,
    required this.onOpen,
    required this.onDismissed,
  });

  final AppNotification notification;
  final String timeLabel;
  final VoidCallback onOpen;
  final VoidCallback onDismissed;

  IconData get _icon => switch (notification.type) {
        NotificationType.reportStatus => Icons.fact_check_outlined,
        NotificationType.actionReminder => Icons.event_available_outlined,
        NotificationType.locationUpdate => Icons.location_on_outlined,
      };

  String _typeLabel(BuildContext context) => switch (notification.type) {
        NotificationType.reportStatus => context.tr('p13.type.reportStatus'),
        NotificationType.actionReminder => context.tr('p13.type.actionReminder'),
        NotificationType.locationUpdate => context.tr('p13.type.locationUpdate'),
      };

  @override
  Widget build(BuildContext context) {
    final unread = !notification.read;

    final tile = Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ListTile(
        key: ValueKey('p13-item-${notification.id}'),
        onTap: onOpen,
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: AppColors.ocean.withValues(alpha: 0.08),
          child: Semantics(
            label: _typeLabel(context),
            child: Icon(_icon, size: 22, color: AppColors.ocean),
          ),
        ),
        title: Text(
          notification.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.inactiveTab,
              ),
            ),
          ],
        ),
        trailing: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: unread
              ? Semantics(
                  label: context.tr('p13.semanticUnread'),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.ocean,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('p13-dismiss-${notification.id}'),
      direction: DismissDirection.endToStart,
      // Delete clears the tile entirely; the list and badge shrink through the
      // same Riverpod state the app bar and shell watch.
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.coral,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        ),
        child: Semantics(
          label: context.tr('p13.delete'),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
      ),
      child: tile,
    );
  }
}
