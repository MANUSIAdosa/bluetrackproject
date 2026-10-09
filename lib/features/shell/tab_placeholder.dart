import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/empty_state.dart';
import 'app_shell.dart';

/// Placeholder body for a shell tab whose full content is not built yet.
///
/// Shows the tab icon, the tab name, and the one-line purpose declared in the
/// App Shell tab configuration ([ShellTabs]) — never a per-page copy — plus a
/// short note that the complete content follows.
class TabPlaceholder extends StatelessWidget {
  const TabPlaceholder({super.key, required this.location});

  /// Tab location key, e.g. `/transparency`.
  final String location;

  @override
  Widget build(BuildContext context) {
    final tab = ShellTabs.byLocation(location);

    if (tab == null) {
      return EmptyState(
        icon: Icons.schedule,
        message: context.tr('common.comingSoon'),
      );
    }

    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          // Keeps the copy readable on wide screens and safe on short ones.
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
                  child: Icon(tab.activeIcon, size: 36, color: AppColors.ocean),
                ),
                const SizedBox(height: 16),
                Text(
                  tab.label(context),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (tab.descriptionKey != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    tab.description(context)!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
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
    );
  }
}