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

  List<_TabSpec> _tabs(BuildContext context) {
    final tabs = [
      _TabSpec(
        location: '/explore',
        label: context.tr('nav.jelajahi'),
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
      ),
      _TabSpec(
        location: '/transparency',
        label: context.tr('nav.transparency'),
        icon: Icons.account_balance_outlined,
        activeIcon: Icons.account_balance,
      ),
    ];

    // Release 2 only: Hibah between Transparansi and Dampakku.
    if (AppConfig.isRelease2) {
      tabs.add(
        _TabSpec(
          location: '/grants',
          label: 'Hibah',
          icon: Icons.volunteer_activism_outlined,
          activeIcon: Icons.volunteer_activism,
        ),
      );
    }

    tabs
      ..add(
        _TabSpec(
          location: '/impact',
          label: context.tr('nav.impact'),
          icon: Icons.favorite_outline,
          activeIcon: Icons.favorite,
        ),
      )
      ..add(
        _TabSpec(
          location: '/profile',
          label: context.tr('nav.profile'),
          icon: Icons.person_outline,
          activeIcon: Icons.person,
        ),
      );
    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs(context);

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
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({
    required this.location,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String location;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}
