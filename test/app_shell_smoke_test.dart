import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:blue_track/app/app.dart';
import 'package:blue_track/core/config/app_config.dart';
import 'package:blue_track/core/state/app_state.dart';

/// P00 shell smoke test (Periode 2 part 2).
///
/// Locale-independent on purpose: the test resolves labels through the widget
/// tree instead of locking to a string, and the offline banner is matched
/// against both locales' copy of `shell.offline`.
void main() {
  // Toggle-switching offline makes Explore reload from Hive (saved projects),
  // which is normally initialized in main() — tests must do it themselves.
  final hiveDir =
      Directory.systemTemp.createTempSync('blue_track_shell_hive');
  setUpAll(() => Hive.init(hiveDir.path));
  tearDownAll(() => hiveDir.deleteSync(recursive: true));

  testWidgets(
    'shell shows the 4 configured tabs, Aksi replaces Transparansi, '
    'offline banner toggles',
    (tester) async {
      // AppShell watches P13 providers (Riverpod): host inside a ProviderScope
      // like main() does. The real mock repository loads below.
      await tester.pumpWidget(
        const ProviderScope(child: BlueTrackApp(onboardingDone: true)),
      );
      // Fixed pumps, not pumpAndSettle: tab pages contain animations that may
      // never fully settle (e.g. FlutterMap tiles in the explore branch).
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      final navBarFinder = find.byType(NavigationBar);
      expect(navBarFinder, findsOneWidget);

      final navBar = tester.widget<NavigationBar>(navBarFinder);
      final destinations = navBar.destinations
          .whereType<NavigationDestination>()
          .toList(growable: false);

      // Task 1+2: tab list comes from TabConfig (part 1) — 4 tabs, all
      // labeled, and the old Transparansi/Transparency tab is gone.
      expect(destinations, hasLength(TabConfig.count));
      expect(destinations, hasLength(4));
      for (final destination in destinations) {
        expect(destination.label, isNotEmpty);
        expect(destination.label, isNot(contains('Transparansi')));
        expect(destination.label, isNot(contains('Transparency')));
      }

      // The Aksi tab uses its shell registry icon (inactive = outlined) and
      // lives at index 1.
      await tester.tap(find.byIcon(Icons.task_alt_outlined));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.widget<NavigationBar>(navBarFinder).selectedIndex,
        1,
        reason: 'Aksi is the second configured tab',
      );
      // Selected nav icon + placeholder icon circle (title + page code).
      expect(find.byIcon(Icons.task_alt), findsNWidgets(2));
      expect(find.text('Transparansi'), findsNothing);
      expect(find.text('Transparency'), findsNothing);

      // Task 5 stays untouched: the bell opens /notifications (covered by the
      // shared NotificationBell navigation), here we just switch back to
      // Jelajahi to prove branch state survives round-trips.
      final exploreTabIcon = find.descendant(
        of: navBarFinder,
        matching: find.byIcon(Icons.explore_outlined),
      );
      await tester.tap(exploreTabIcon);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<NavigationBar>(navBarFinder).selectedIndex,
        0,
        reason: 'round-trip returns to Jelajahi',
      );

      // Task 6: thin offline banner driven by the offline controller.
      const offlineTexts = <String>[
        'Mode offline - menampilkan data tersimpan',
        'Offline mode - showing saved data',
      ];
      final bannerText = find.byWidgetPredicate(
        (widget) => widget is Text && offlineTexts.contains(widget.data),
      );

      OfflineController.instance.setOffline(true);
      await tester.pump(const Duration(milliseconds: 200));
      expect(bannerText, findsOneWidget);

      OfflineController.instance.setOffline(false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(bannerText, findsNothing);
    },
  );
}
