import 'package:blue_track/core/config/app_config.dart';
import 'package:blue_track/core/theme/app_colors.dart';
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
  group('Choose Interests layout', () {
    /// 390x844 at dpr 2 is a typical phone; the interest screen must fit
    /// without scrolling.
    void phoneSurface(WidgetTester tester) {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(780, 1688);
      addTearDown(tester.view.reset);
    }

    Future<void> pumpInterests(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapPage(const OnboardingPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Lewati'));
      await tester.pumpAndSettle();
    }

    testWidgets('all five interests fit on a standard phone without scrolling',
        (tester) async {
      phoneSurface(tester);
      await pumpInterests(tester);

      for (final label in [
        'Penyu',
        'Karang',
        'Mangrove',
        'Mamalia laut',
        'Lamun',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '"$label" should be visible',
        );
      }

      // Every card fully inside the viewport.
      final screenHeight = tester.view.physicalSize.height /
          tester.view.devicePixelRatio;
      for (final label in [
        'Penyu',
        'Karang',
        'Mangrove',
        'Mamalia laut',
        'Lamun',
      ]) {
        final box = tester.getRect(find.text(label));
        expect(
          box.bottom,
          lessThanOrEqualTo(screenHeight),
          reason: '"$label" is cut off at the bottom',
        );
      }
    });

    testWidgets('the grid scrolls if the text scale makes it overflow', (
      tester,
    ) async {
      phoneSurface(tester);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        wrapPage(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: const OnboardingPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Lewati'));
      await tester.pumpAndSettle();

      // Large text must not throw a layout overflow.
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses two columns with the fifth card spanning the row', (
      tester,
    ) async {
      phoneSurface(tester);
      await pumpInterests(tester);

      final penyu = tester.getRect(find.text('Penyu'));
      final karang = tester.getRect(find.text('Karang'));
      final mangrove = tester.getRect(find.text('Mangrove'));
      final mamalia = tester.getRect(find.text('Mamalia laut'));
      final lamun = tester.getRect(find.text('Lamun'));

      // Same row: side by side, equal height.
      expect(penyu.top, closeTo(karang.top, 0.5));
      expect(karang.left, greaterThan(penyu.left));
      expect(penyu.width, closeTo(karang.width, 0.5));
      expect(penyu.height, closeTo(karang.height, 0.5));

      // Second row starts below the first.
      expect(mangrove.top, greaterThan(penyu.bottom));

      // The odd fifth card spans the full width, matching row 1's extent.
      expect(lamun.left, closeTo(penyu.left, 0.5));
      expect(
        lamun.right,
        closeTo(mamalia.right, 1.0),
        reason: 'Lamun should span the whole row',
      );
      expect(lamun.width, greaterThan(mamalia.width));
    });

    testWidgets('cards are compact: much wider than tall', (tester) async {
      phoneSurface(tester);
      await pumpInterests(tester);

      final card = tester.getRect(find.text('Penyu'));
      expect(card.width / card.height, greaterThan(2.0));
    });

    testWidgets('the icon sits to the left of the label', (tester) async {
      phoneSurface(tester);
      await pumpInterests(tester);

      // Mangrove keeps a Material icon.
      final icon = tester.getRect(find.byIcon(Icons.forest));
      final label = tester.getRect(find.text('Mangrove'));
      expect(icon.left, lessThan(label.left));
      expect(icon.center.dy, closeTo(label.center.dy, 12));
    });

    testWidgets('Material icons where available, emoji for the rest', (
      tester,
    ) async {
      phoneSurface(tester);
      await pumpInterests(tester);

      // Mangrove and seagrass have close Material matches.
      expect(find.byIcon(Icons.forest), findsOneWidget);
      expect(find.byIcon(Icons.grass), findsOneWidget);

      // Penyu, karang, and marine mammals have no Material glyph.
      expect(find.text('🐢'), findsOneWidget);
      expect(find.text('🪸'), findsOneWidget);
      expect(find.text('🐬'), findsOneWidget);
    });
  });

  group('interest selection states', () {
    Future<void> pumpInterests(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrapPage(const OnboardingPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Lewati'));
      await tester.pumpAndSettle();
    }

    testWidgets('"Pilih minimal satu" stays until something is selected', (
      tester,
    ) async {
      await pumpInterests(tester);

      expect(find.text('Pilih minimal satu'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Mulai'))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Karang'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih minimal satu'), findsNothing);
    });

    testWidgets('Start is enabled once at least one interest is picked', (
      tester,
    ) async {
      await pumpInterests(tester);

      await tester.tap(find.text('Lamun'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Mulai'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('deselecting every interest disables Start again', (
      tester,
    ) async {
      await pumpInterests(tester);

      await tester.tap(find.text('Lamun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lamun'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih minimal satu'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Mulai'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('selected cards are ocean/teal, unselected stay plain', (
      tester,
    ) async {
      await pumpInterests(tester);
      await tester.tap(find.text('Penyu'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(4));

      // The selected card paints the onboarding ocean-to-teal gradient; the
      // four unselected ones paint none.
      final gradients = tester
          .widgetList<Ink>(find.byType(Ink))
          .map((ink) => ink.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.gradient != null)
          .toList();
      expect(gradients, hasLength(1));
      final gradient = gradients.single.gradient! as LinearGradient;
      expect(gradient.colors, [AppColors.ocean, AppColors.teal]);

      // Unselected cards stay plain white with a light border.
      final plain = tester
          .widgetList<Ink>(find.byType(Ink))
          .map((ink) => ink.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.gradient == null)
          .toList();
      expect(plain, hasLength(4));
    });

    testWidgets('the check marks move as interests are toggled', (
      tester,
    ) async {
      await pumpInterests(tester);

      await tester.tap(find.text('Penyu'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.text('Karang'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

      await tester.tap(find.text('Penyu'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(4));
    });

    testWidgets('the selected card uses white text, unselected dark', (
      tester,
    ) async {
      await pumpInterests(tester);
      await tester.tap(find.text('Penyu'));
      await tester.pumpAndSettle();

      final selected = tester.widget<Text>(find.text('Penyu'));
      final unselected = tester.widget<Text>(find.text('Karang'));
      expect(selected.style?.color, Colors.white);
      expect(unselected.style?.color, AppColors.textPrimary);
    });
  });

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

    testWidgets('the back arrow is hidden on the first slide', (tester) async {
      await pumpOnboarding(tester);

      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('the back arrow returns from slide 2 to slide 1', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await goToSecondSlide(tester);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('Terumbu Karang Rumah Ikan'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Laut Menyerap Karbon'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('the back arrow walks all the way back to slide 1', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await goToSecondSlide(tester);
      await tapPrimary(tester);
      expect(find.text('Penyu Butuh Bantuanmu'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Terumbu Karang Rumah Ikan'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Laut Menyerap Karbon'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('going back to slide 1 restores its "Berikutnya" label', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await goToSecondSlide(tester);
      await tapPrimary(tester);
      expect(find.widgetWithText(FilledButton, 'Pilih Minat'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Berikutnya'), findsOneWidget);
    });

    testWidgets('the back arrow is not a second primary button', (
      tester,
    ) async {
      await pumpOnboarding(tester);
      await goToSecondSlide(tester);

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('system back on a slide steps back one slide', (tester) async {
      await pumpOnboarding(tester);
      await goToSecondSlide(tester);
      await tapPrimary(tester);
      expect(find.text('Penyu Butuh Bantuanmu'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Terumbu Karang Rumah Ikan'), findsOneWidget);
      expect(find.text('Penyu Butuh Bantuanmu'), findsNothing);
    });

    testWidgets('skip still works after stepping back', (tester) async {
      await pumpOnboarding(tester);
      await goToSecondSlide(tester);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Lewati'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Mulai'), findsOneWidget);
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