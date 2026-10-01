import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';

/// Notification bell with optional count badge (P00 shell requirement;
/// opens P13, which is a stub during Subproject 01).
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final count = AppConfig.unreadNotifications;
    final bell = IconButton(
      tooltip: 'Notification',
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () => context.push('/notifications'),
    );

    if (count <= 0) return bell;

    return Badge(
      label: Text('$count'),
      child: bell,
    );
  }
}
