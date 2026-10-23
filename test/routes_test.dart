import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'package:blue_track/app/app.dart';
import 'package:blue_track/features/actions/presentation/action_detail_page.dart';
import 'package:blue_track/features/actions/presentation/actions_page.dart';
import 'package:blue_track/features/explore/presentation/explore_page.dart';
import 'package:blue_track/features/onboarding/presentation/onboarding_page.dart';
import 'package:blue_track/features/settings/presentation/settings_page.dart';
import 'package:blue_track/features/support/presentation/donation_trace_page.dart';

/// Part 3 navigation contract: onboarding redirect, non-tab detail routes,
/// parameter passing, `/actions` vs `/actions/:id`, and safe back buttons.
///
/// Locale-independent on purpose: placeholder parameter rows render
/// `placeholder.paramValue`, whose pattern is identical in both locales.
void main() {
  // Explore loads saved projects from Hive on rebuild, which main() normally
  // initializes — tests must point Hive at a temp directory themselves.
  final hiveDir = Directory.systemTemp.createTempSync('blue_track_routes_hive');
  setUpAll(() => Hive.init(hiveDir.path));
  tearDownAll(() => hiveDir.deleteSync(recursive: true));

  Future<void> pumpApp(
    WidgetTester tester, {
    required bool onboardingDone,
  }) async {
    // AppShell watches P13 providers (Riverpod): host inside a ProviderScope
    // like main() does.
    await tester.pumpWidget(
      ProviderScope(child: BlueTrackApp(onboardingDone: onboardingDone)),
    );
    // Fixed pumps, not pumpAndSettle: the explore branch embeds animated
    // content that may never fully settle under the test binding.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  BuildContext routerContextOf(WidgetTester tester, Type anchor) =>
      tester.element(find.byType(anchor));

  Future<void> navigation(
    WidgetTester tester,
    BuildContext context,
    String url,
  ) async {
    GoRouter.of(context).go(url);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'onboarding not done: any other location is redirected to /onboarding',
    (tester) async {
      await pumpApp(tester, onboardingDone: false);

      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      // Even a deep drop to a detail page bounces back — no shell leaks.
      await navigation(tester,
          routerContextOf(tester, OnboardingPage), '/explore');
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await navigation(tester,
          routerContextOf(tester, OnboardingPage), '/project/proj-42');
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets(
    'onboarding done: /onboarding itself is redirected to Explore',
    (tester) async {
      await pumpApp(tester, onboardingDone: true);

      // The app must not force onboarding again — go to it explicitly.
      await navigation(
        tester,
        routerContextOf(tester, NavigationBar),
        '/onboarding',
      );

      expect(find.byType(ExplorePage), findsOneWidget);
      expect(find.byType(OnboardingPage), findsNothing);
    },
  );

  testWidgets(
    'dynamic parameters reach the right placeholder, in order',
    (tester) async {
      await pumpApp(tester, onboardingDone: true);

      await navigation(tester, routerContextOf(tester, NavigationBar),
          '/actions/aksi-001');
      expect(find.byType(ActionDetailPage), findsOneWidget);
      expect(find.text('id: aksi-001'), findsOneWidget);

      // Next route from scratch — parameter must not leak from the previous.
      // The shell is gone on a detail page, so resolve the context from the
      // page that is actually on screen.
      await navigation(tester, routerContextOf(tester, ActionDetailPage),
          '/support/trace/don-77');
      expect(find.byType(DonationTracePage), findsOneWidget);
      expect(find.text('donationId: don-77'), findsOneWidget);
      expect(find.text('id: aksi-001'), findsNothing);
    },
  );

  testWidgets(
    '/actions opens the tab branch; /actions/:id opens the detail placeholder '
    'outside the shell',
    (tester) async {
      await pumpApp(tester, onboardingDone: true);
      final context = routerContextOf(tester, NavigationBar);

      await navigation(tester, context, '/actions');
      expect(find.byType(ActionsPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      await navigation(tester, context, '/actions/aksi-001');
      expect(find.byType(ActionDetailPage), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(ActionsPage), findsNothing);
    },
  );

  testWidgets(
    'non-tab detail page has a back button; on a bare route it falls back '
    'to Explore without throwing',
    (tester) async {
      await pumpApp(tester, onboardingDone: true);
      final context = routerContextOf(tester, NavigationBar);

      await navigation(tester, context, '/settings');
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ExplorePage), findsOneWidget);
      expect(find.byType(SettingsPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
