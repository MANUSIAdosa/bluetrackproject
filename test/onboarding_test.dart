import 'package:blue_track/core/config/app_config.dart';
import 'package:blue_track/features/onboarding/presentation/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_harness.dart';

Future<void> pumpOnboarding(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(wrapPage(const OnboardingPage()));
  await tester.pumpAndSettle();
}

/// Taps the primary button on the current slide, easing past the page animation.
Future<void> tapPrimary(WidgetTester tester) async {
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

/// Moves from slide 1 to slide 2.
Future<void> goToSecondSlide(WidgetTester tester) async {
  await tapPrimary(tester);
  await tester.pumpAndSettle();
}

void main() {
  group('onboarding button labels', () {
    testWidgets('slides 1-2 say "Berikutnya", slide 3 says "Pilih Minat"', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      expect(find.widgetWithText(FilledButton, 'Berikutnya'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Pilih Minat'), findsNothing);

      await goToSecondSlide(tester);
      expect(find.widgetWithText(FilledButton, 'Berikutnya'), findsOneWidget);

      await tapPrimary(tester);
      expect(find.widgetWithText(FilledButton, 'Pilih Minat'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Berikutnya'), findsNothing);
    });

    testWidgets('the interest screen says "Mulai"', (tester) async {
      await pumpOnboarding(tester);
      await goToSecondSlide(tester);
      await tapPrimary(tester);
      await tapPrimary(tester);

      expect(find.widgetWithText(FilledButton, 'Mulai'), findsOneWidget);
    });

    testWidgets('"Lewati" is a text button, not a primary button', (
      tester,
    ) async {
      await pumpOnboarding(tester);

      expect(find.widgetWithText(TextButton, 'Lewati'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Lewati'), findsNothing);
    });

    testWidgets('each screen has exactly one primary button', (tester) async {
      await pumpOnboarding(tester);
      expect(find.byType(FilledButton), findsOneWidget);

      await goToSecondSlide(tester);
      expect(find.byType(FilledButton), findsOneWidget);

      await tapPrimary(tester);
      await tapPrimary(tester);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('skip', () {
    testWidgets('goes to the interest screen instead of finishing', (
      tester,
    ) async {
      await pumpOnboarding(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Lewati'));
      await tester.pumpAndSettle();

      // Landed on the interest screen...
      expect(find.widgetWithText(FilledButton, 'Mulai'), findsOneWidget);
      expect(find.text('Pilih Minatmu'), findsOneWidget);
      // ...not on the slides, and not on Explore.
      expect(find.text('Laut Menyerap Karbon'), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('does not mark onboarding as done', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpOnboarding(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Lewati'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(AppConfig.onboardingDoneKey),
        isNull,
        reason: 'Skip must not complete onboarding',
      );
    });

    testWidgets('Start still requires at least one interest', (tester) async {
      await pumpOnboarding(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Lewati'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih minimal satu'), findsOneWidget);
      final start = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Mulai'),
      );
      expect(start.onPressed, isNull);
    });
  });

  group('back navigation', () {
    testWidgets('the back arrow returns to the last slide', (tester) async {
      await pumpOnboarding(tester);
      await goToSecondSlide(tester);
      await tapPrimary(tester);
      await tapPrimary(tester);
      expect(find.text('Pilih Minatmu'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Minatmu'), findsNothing);
      // Back on slide 3, with its own primary label restored.
      expect(find.text('Penyu Butuh Bantuanmu'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Pilih Minat'), findsOneWidget);
    });

    testWidgets('the back arrow is not a second primary button', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await goToSecondSlide(tester);
      await tapPrimary(tester);
      await tapPrimary(tester);

      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('returning to the slides keeps selected interests', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await goToSecondSlide(tester);
      await tapPrimary(tester);
      await tapPrimary(tester);

      await tester.tap(find.text('Penyu'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tapPrimary(tester);

      expect(find.text('Mulai'), findsOneWidget);
      final start = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Mulai'),
      );
      expect(
        start.onPressed,
        isNotNull,
        reason: 'The earlier selection should survive going back',
      );
    });

    testWidgets('system back on the interest screen returns to the slides', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await goToSecondSlide(tester);
      await tapPrimary(tester);
      await tapPrimary(tester);
      expect(find.text('Pilih Minatmu'), findsOneWidget);

      // Simulates the platform back gesture.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Pilih Minatmu'), findsNothing);
      expect(find.text('Penyu Butuh Bantuanmu'), findsOneWidget);
    });
  });

  group('after Start', () {
    testWidgets('lands on /explore and cannot return to onboarding', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const OnboardingPage(),
          ),
          GoRoute(path: '/explore', builder: (context, state) => const Text('Explore')),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(wrapRouter(router));
      await tester.pumpAndSettle();

      await goToSecondSlide(tester);
      await tapPrimary(tester);
      await tapPrimary(tester);

      await tester.tap(find.text('Penyu'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Mulai'));
      await tester.pumpAndSettle();

      expect(find.text('Explore'), findsOneWidget);

      // Back must not reopen onboarding.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Pilih Minatmu'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConfig.onboardingDoneKey), isTrue);
      expect(prefs.getStringList(AppConfig.interestsKey), ['penyu']);
    });
  });
}