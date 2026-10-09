import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// P13 Notifications — temporary page.
///
/// Notifications currently mean news about the user's donations, so the page
/// says so instead of showing only the generic "coming soon" line. Deliberately
/// not a list: no notification items, no read marking, no types — those belong
/// to the week P13 is actually assigned.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('notifications.title'))),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.ocean.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      size: 36,
                      color: AppColors.ocean,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('notifications.donationNews'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('common.comingSoon'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.inactiveTab,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}