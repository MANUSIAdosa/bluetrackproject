import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';

/// Notification bell with an unread-count badge (P00 shell requirement).
///
/// The count comes from [NotificationsController] — never from a constant in
/// AppConfig — so the bell and the My Impact nav badge can never disagree.
/// Zero renders no badge. The tooltip follows the active locale.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final bell = IconButton(
      tooltip: context.tr('shell.notifications'),
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () => context.push('/notifications'),
    );

    return ListenableBuilder(
      listenable: NotificationsController.instance,
      builder: (context, child) {
        final count = NotificationsController.instance.unreadCount;
        if (count <= 0) return bell;

        return Badge(
          backgroundColor: AppColors.coral,
          textColor: Colors.white,
          label: Text('$count'),
          child: child,
        );
      },
      child: bell,
    );
  }
}