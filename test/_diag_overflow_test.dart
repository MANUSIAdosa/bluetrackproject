import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blue_track/features/onboarding/presentation/onboarding_page.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('diagnose overflow at 320x640 scale 1.5', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrapPage(const OnboardingPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Lewati'));
    await tester.pumpAndSettle();

    void probe(String name, Finder finder) {
      try {
        final rect = tester.getRect(finder);
        // ignore: avoid_print
        print('PROBE $name: $rect');
      } catch (e) {
        // ignore: avoid_print
        print('PROBE $name: NOT FOUND');
      }
    }

    probe('backIcon', find.byIcon(Icons.arrow_back));
    probe('titleText', find.text('Pilih Minatmu'));
    probe('labelText', find.text('Info Detail'));
    probe('fullLabelText', find.text('Informasi Detail'));
    probe('title', find.byKey(const ValueKey('p01.interests.titleHeader')));
    probe('infoButton', find.byKey(const ValueKey('p01.interests.infoButton')));
    probe('introText', find.text('Pilih topik lautmu agar proyek terkait '
        'muncul lebih dulu di Jelajahi. Ubah di Profil.'));
    probe('subtitle', find.byKey(const ValueKey('p01.interests.subtitle')));
    probe('startBtn', find.widgetWithText(FilledButton, 'Mulai'));
    // Any long-wrapped text candidates:
    for (final id in const [
      'sampah_laut',
      'terumbu_karang',
      'mangrove',
      'perikanan',
      'satwa_laut',
    ]) {
      probe('caption-$id', find.byKey(ValueKey('interest.caption.$id')));
    }
  });
}
