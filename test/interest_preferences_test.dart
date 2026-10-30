import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:blue_track/core/config/app_config.dart';
import 'package:blue_track/core/router/app_router.dart';
import 'package:blue_track/core/router/routes.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/onboarding/presentation/onboarding_page.dart';
import 'package:blue_track/features/onboarding/data/ocean_facts_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_harness.dart';

void main() {
  late Directory hiveDir;
  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('interest_preferences');
    Hive.init(hiveDir.path);
    await Hive.openBox<dynamic>(AppConfig.savedProjectsBox);
  });
  tearDownAll(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OnboardingState.interests.value = [];
    OceanFactsRepository.loader = (_) async => [
      const OnboardingSlide(key: 'one', title: 'One', body: 'One'),
      const OnboardingSlide(key: 'two', title: 'Two', body: 'Two'),
      const OnboardingSlide(key: 'three', title: 'Three', body: 'Three'),
    ];
  });
  tearDown(
    () => OceanFactsRepository.loader = OceanFactsRepository.loadFromAsset,
  );

  testWidgets('skip completes onboarding and stays complete after reopening', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: Routes.onboarding,
      routes: [
        GoRoute(
          path: Routes.onboarding,
          builder: (_, _) => const OnboardingPage(),
        ),
        GoRoute(
          path: Routes.explore,
          builder: (_, _) => const Text('Explore destination'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Lewati'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('interest.option.mangrove')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Lewati'));
    await tester.pumpAndSettle();
    expect(find.text('Explore destination'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppConfig.onboardingDoneKey), isTrue);
    expect(prefs.getStringList(AppConfig.interestsKey), isEmpty);
    expect(OnboardingController.instance.done, isTrue);
    final restarted = createRouter(
      onboardingDone: prefs.getBool(AppConfig.onboardingDoneKey)!,
    );
    addTearDown(restarted.dispose);
    await tester.pumpWidget(wrapRouter(restarted));
    await tester.pump(const Duration(milliseconds: 400));
    expect(restarted.routeInformationProvider.value.uri.path, Routes.explore);
    expect(find.byType(OnboardingPage), findsNothing);
  });

  testWidgets(
    'Profile opens saved interests; save, reopen, cancel and clear work',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        AppConfig.onboardingDoneKey: true,
        AppConfig.interestsKey: ['mangrove'],
      });
      final router = createRouter(onboardingDone: true)..go(Routes.profile);
      addTearDown(router.dispose);
      await tester.pumpWidget(wrapRouter(router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preferensi Minat'));
      await tester.pumpAndSettle();
      expect(
        GoRouterState.of(tester.element(find.byType(OnboardingPage))).uri.path,
        Routes.interests,
      );
      expect(find.byType(PageView), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('interest.option.terumbu_karang')),
      );
      await tester.tap(find.text('Simpan minat'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, Routes.profile);
      expect(
        await OnboardingState.readInterests(),
        containsAll(['mangrove', 'terumbu_karang']),
      );
      expect(
        OnboardingState.interests.value,
        containsAll(['mangrove', 'terumbu_karang']),
      );

      await tester.tap(find.text('Preferensi Minat'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      await tester.tap(
        find.byKey(const ValueKey('interest.option.sampah_laut')),
      );
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(
        await OnboardingState.readInterests(),
        isNot(contains('sampah_laut')),
      );

      await tester.tap(find.text('Preferensi Minat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('interest.option.mangrove')));
      await tester.tap(
        find.byKey(const ValueKey('interest.option.terumbu_karang')),
      );
      await tester.tap(find.text('Simpan minat'));
      await tester.pumpAndSettle();
      expect(await OnboardingState.readInterests(), isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          AppConfig.onboardingDoneKey,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'bundled photos match topics; hover glow clears, selected glow remains',
    (tester) async {
      await tester.pumpWidget(
        wrapPage(const OnboardingPage(editInterests: true)),
      );
      await tester.pumpAndSettle();
      const assets = {
        'sampah_laut': 'marine_waste.jpg',
        'terumbu_karang': 'coral_reef.jpg',
        'mangrove': 'mangrove.jpg',
        'perikanan': 'sustainable_fishery.jpg',
        'satwa_laut': 'marine_wildlife.jpg',
      };
      for (final entry in assets.entries) {
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byKey(ValueKey('interest.block.${entry.key}')),
            matching: find.byType(Image),
          ),
        );
        final path = (image.image as AssetImage).assetName;
        expect(path, 'assets/images/interests/${entry.value}');
        final bytes = await tester.runAsync(() => rootBundle.load(path));
        expect(bytes!.lengthInBytes, greaterThan(0));
      }
      final block = find.byKey(const ValueKey('interest.block.mangrove'));
      bool hasGlow() =>
          (tester.widget<AnimatedContainer>(block).decoration! as BoxDecoration)
              .boxShadow!
              .isNotEmpty;
      expect(hasGlow(), isFalse);
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      await pointer.moveTo(tester.getCenter(block));
      await tester.pumpAndSettle();
      expect(hasGlow(), isTrue);
      await pointer.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(hasGlow(), isFalse);
      await tester.tap(block);
      await tester.pumpAndSettle();
      expect(hasGlow(), isTrue);
      await pointer.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
}
