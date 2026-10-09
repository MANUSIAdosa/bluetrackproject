import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/localization/app_localizations.dart';
import '../../shared/widgets/offline_banner.dart';

/// P00 — App Shell with bottom navigation.
///
/// - Release 1: 4 tabs; the Hibah tab only exists behind [AppConfig.isRelease2].
/// - Tab count is derived from a single release flag, not duplicated widgets.
/// - Offline banner sits above tab content.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  List<ShellTab> _tabs() => ShellTabs.active;

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs();

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: shell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          // Re-tapping the active tab pops it back to its root.
          initialLocation: index == shell.currentIndex,
        ),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.activeIcon),
              label: tab.label(context),
            ),
        ],
      ),
    );
  }
}

/// Configuration of one bottom-navigation tab.
///
/// Lives here so the tab label, icon, and one-line purpose are defined once:
/// the shell renders the navigation bar, and placeholder tab pages read the
/// same spec through [TabPlaceholder].
@immutable
class ShellTab {
  const ShellTab({
    required this.location,
    required this.labelKey,
    required this.icon,
    required this.activeIcon,
    this.descriptionKey,
  });

  final String location;
  final String labelKey;
  final IconData icon;
  final IconData activeIcon;

  /// Localization key of the tab's purpose sentence. Null when the tab has no
  /// placeholder copy of its own.
  final String? descriptionKey;

  String label(BuildContext context) => context.tr(labelKey);

  String? description(BuildContext context) =>
      descriptionKey == null ? null : context.tr(descriptionKey!);
}

/// Release-gated tab list — the single source of truth for the bottom nav.
abstract final class ShellTabs {
  static const ShellTab explore = ShellTab(
    location: '/explore',
    labelKey: 'nav.jelajahi',
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore,
  );

  static const ShellTab transparency = ShellTab(
    location: '/transparency',
    labelKey: 'nav.transparency',
    descriptionKey: 'nav.transparency.description',
    icon: Icons.account_balance_outlined,
    activeIcon: Icons.account_balance,
  );

  /// Release 2 only: Hibah between Transparansi and Dampakku.
  static const ShellTab grants = ShellTab(
    location: '/grants',
    labelKey: 'nav.grants',
    icon: Icons.volunteer_activism_outlined,
    activeIcon: Icons.volunteer_activism,
  );

  static const ShellTab impact = ShellTab(
    location: '/impact',
    labelKey: 'nav.impact',
    descriptionKey: 'nav.impact.description',
    icon: Icons.favorite_outline,
    activeIcon: Icons.favorite,
  );

  static const ShellTab profile = ShellTab(
    location: '/profile',
    labelKey: 'nav.profile',
    descriptionKey: 'nav.profile.description',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
  );

  static List<ShellTab> get active => [
    explore,
    transparency,
    if (AppConfig.isRelease2) grants,
    impact,
    profile,
  ];

  static ShellTab? byLocation(String location) {
    for (final tab in active) {
      if (tab.location == location) return tab;
    }
    return null;
  }
}
