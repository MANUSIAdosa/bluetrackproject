import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../features/notification/application/notification_providers.dart';

/// Notification bell with an unread-count badge (P00 shell requirement).
///
/// The count comes from [unreadCountProvider] — Riverpod state derived from
/// the P13 notification list, the same source the shell tab badge reads — so
/// the bell and the badge can never disagree. Zero renders no badge. The
/// tooltip follows the active locale.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider);

    final bell = IconButton(
      tooltip: context.tr('shell.notifications'),
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () => context.push('/notifications'),
    );

    if (count <= 0) return bell;

    return Badge(
      backgroundColor: AppColors.coral,
      textColor: Colors.white,
      label: Text('$count'),
      child: bell,
    );
  }
}
