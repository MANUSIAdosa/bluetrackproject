import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../features/notification/application/notification_providers.dart';
import '../../shared/widgets/offline_banner.dart';

/// P00 — App Shell with bottom navigation.
///
/// - Release 1: 4 tabs; the Hibah tab only exists behind [AppConfig.isRelease2].
/// - Tab count is derived from a single release flag, not duplicated widgets.
/// - Offline banner sits above tab content.
/// - The unread badge reads [unreadCountProvider] — Riverpod state derived
///   from the P13 notification list. This shell, built at the single
///   StatefulShellRoute branch in `core/router/app_router.dart`, is the one
///   integration point for the navigation badge (P13 part 5/6).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  List<ShellTab> _tabs() => ShellTabs.active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = _tabs();
    // Watching here alone drives every destination's badge; the count is
    // shared with the app-bar bell through the same provider.
    final unreadCount = ref.watch(unreadCountProvider);

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
              icon: _destinationIcon(tab, unreadCount),
              selectedIcon: _destinationIcon(tab, unreadCount, selected: true),
              label: tab.label(context),
            ),
        ],
      ),
    );
  }

  /// Wraps the tab icon in the unread badge when the tab opts in
  /// ([ShellTab.showsUnreadBadge]) and the count is above zero.
  Widget _destinationIcon(ShellTab tab, int unreadCount, {bool selected = false}) {
    final icon = Icon(selected ? tab.activeIcon : tab.icon);
    if (!tab.showsUnreadBadge || unreadCount <= 0) return icon;

    return Badge(
      backgroundColor: AppColors.coral,
      textColor: Colors.white,
      label: Text('$unreadCount'),
      child: icon,
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
    this.showsUnreadBadge = false,
  });

  final String location;
  final String labelKey;
  final IconData icon;
  final IconData activeIcon;

  /// Localization key of the tab's purpose sentence. Null when the tab has no
  /// placeholder copy of its own.
  final String? descriptionKey;

  /// Whether this tab shows the unread-notification badge. Only My Impact does
  /// for now: the bell already covers the other tabs' app bars.
  ///
  /// TODO(P00-part-2): badge tab carrier kept from the Week-2 decision
  /// (Dampakku) — confirm with the product owner under the revised concept.
  final bool showsUnreadBadge;

  String label(BuildContext context) => context.tr(labelKey);

  String? description(BuildContext context) =>
      descriptionKey == null ? null : context.tr(descriptionKey!);
}

/// Bottom-nav tab registry (UI binding + Release 2 gate).
///
/// WHICH tabs are active comes from `TabConfig` in `core/config/app_config.dart`:
/// its release flags build the active list and its length — never duplicated
/// here. This class only binds each configured tab id to its shell UI
/// (icon, label, location); the Release 2 tab stays under [AppConfig.isRelease2].
abstract final class ShellTabs {
  static const ShellTab explore = ShellTab(
    location: Routes.explore,
    labelKey: 'nav.jelajahi',
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore,
  );

  /// Aksi tab — replaces the former Transparansi tab (revised concept:
  /// Lapor → Pantau → Aksi → Dukung). TODO(P00-part-2): confirm icon.
  static const ShellTab actions = ShellTab(
    location: Routes.actionAgenda,
    labelKey: 'nav.aksi',
    descriptionKey: 'nav.aksi.description',
    icon: Icons.task_alt_outlined,
    activeIcon: Icons.task_alt,
  );

  /// Release 2 only: Hibah between Transparansi and Dampakku.
  static const ShellTab grants = ShellTab(
    location: '/grants',
    labelKey: 'nav.grants',
    icon: Icons.volunteer_activism_outlined,
    activeIcon: Icons.volunteer_activism,
  );

  static const ShellTab impact = ShellTab(
    location: Routes.impact,
    labelKey: 'nav.impact',
    descriptionKey: 'nav.impact.description',
    icon: Icons.favorite_outline,
    activeIcon: Icons.favorite,
    showsUnreadBadge: true,
  );

  static const ShellTab profile = ShellTab(
    location: Routes.profile,
    labelKey: 'nav.profile',
    descriptionKey: 'nav.profile.description',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
  );

  /// Active tabs in configuration order (see [TabConfig.active]) plus the
  /// Release 2 tab behind its own overall release flag.
  static List<ShellTab> get active {
    // One binding per configured tab id — never a second tab list.
    const byConfigId = <String, ShellTab>{
      'jelajahi': explore,
      'aksi': actions,
      'dampakku': impact,
      'profil': profile,
    };
    return [
      for (final configTab in TabConfig.active) byConfigId[configTab.id]!,
      if (AppConfig.isRelease2) grants,
    ];
  }

  static ShellTab? byLocation(String location) {
    for (final tab in active) {
      if (tab.location == location) return tab;
    }
    return null;
  }
}
