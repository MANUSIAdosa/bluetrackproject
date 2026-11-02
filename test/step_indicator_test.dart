import 'package:blue_track/core/theme/app_colors.dart';
import 'package:blue_track/shared/widgets/step_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Widget tests default to the Ahem font, whose glyphs are all squares. Load
  // the real app font so "does this label fit?" reflects what users see.
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await loader.load();
  });

  Future<void> pumpIndicator(
    WidgetTester tester, {
    required List<String> labels,
    int current = 0,
    double width = 320,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapPage(
        Padding(
          padding: const EdgeInsets.all(16),
          child: StepIndicator(labels: labels, current: current),
        ),
      ),
    );
    await tester.pump();
  }

  void expectLabelFits(WidgetTester tester, String label) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason:
          'Label "$label" terpotong (lebar kolom ${paragraph.size.width} dp)',
    );
  }

  testWidgets('keeps every wizard label visible at 320dp', (tester) async {
    const labels = ['Foto', 'Lokasi', 'Jenis', 'Tinjau'];
    await pumpIndicator(tester, labels: labels);

    for (final label in labels) {
      expectLabelFits(tester, label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the longest donation label visible at 320dp', (
    tester,
  ) async {
    const labels = ['Nominal', 'Tujuan', 'Konfirmasi', 'Hasil'];
    await pumpIndicator(tester, labels: labels);

    for (final label in labels) {
      expectLabelFits(tester, label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the English labels visible at 320dp', (tester) async {
    const labels = ['Amount', 'Purpose', 'Confirmation', 'Result'];
    await pumpIndicator(tester, labels: labels);

    for (final label in labels) {
      expectLabelFits(tester, label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('marks completed steps and highlights the active label', (
    tester,
  ) async {
    await pumpIndicator(
      tester,
      labels: const ['Foto', 'Lokasi', 'Jenis', 'Tinjau'],
      current: 2,
    );

    expect(find.byIcon(Icons.check), findsNWidgets(2));

    final active = tester.widget<Text>(find.text('Jenis'));
    expect(active.style?.color, AppColors.ocean);
    expect(active.style?.fontWeight, FontWeight.w700);

    final pending = tester.widget<Text>(find.text('Tinjau'));
    expect(pending.style?.color, AppColors.textSecondary);
  });

  testWidgets('numbers the steps from one', (tester) async {
    await pumpIndicator(
      tester,
      labels: const ['Foto', 'Lokasi', 'Jenis', 'Tinjau'],
      current: 0,
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });
}
