import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/explore/domain/explore_map_data.dart';
import 'package:blue_track/features/explore/presentation/widgets/filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

/// Opens the sheet the way the page does and captures what it returns.
Future<void> openSheet(
  WidgetTester tester, {
  required void Function(ExploreFilterSelection?) onResult,
  String category = 'semua',
  DistanceBand distance = DistanceBand.semua,
  ProjectCondition? condition,
}) async {
  await tester.pumpWidget(
    wrapPage(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            onResult(
              await showExploreFilterSheet(
                context,
                categoryIds: const ['semua', 'penyu', 'karang'],
                selection: ExploreFilterSelection(
                  category: category,
                  distance: distance,
                  condition: condition,
                ),
                userLocationLabel: 'Jakarta',
              ),
            );
          },
          child: const Text('buka'),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sheet shows a section per filter group', (tester) async {
    await openSheet(tester, onResult: (_) {});

    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Jarak'), findsOneWidget);
    expect(find.text('Status kondisi'), findsOneWidget);
    expect(find.text('Terapkan'), findsOneWidget);
    expect(find.text('Atur ulang'), findsOneWidget);
  });

  testWidgets('the distance section names the mock reference location', (
    tester,
  ) async {
    await openSheet(tester, onResult: (_) {});

    expect(find.textContaining('Jakarta'), findsOneWidget);
  });

  testWidgets('picking a condition and applying returns the selection', (
    tester,
  ) async {
    ExploreFilterSelection? result;
    await openSheet(tester, onResult: (value) => result = value);

    await tester.tap(find.text('Kritis'));
    await tester.pump();
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.condition, ProjectCondition.kritis);
    expect(result!.distance, DistanceBand.semua);
    expect(result!.category, 'semua');
  });

  testWidgets('picking a distance band keeps the category', (tester) async {
    ExploreFilterSelection? result;
    await openSheet(
      tester,
      onResult: (value) => result = value,
      category: 'karang',
    );

    await tester.tap(find.text('250–1000 km'));
    await tester.pump();
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();

    expect(result!.distance, DistanceBand.sedang);
    expect(result!.category, 'karang');
  });

  testWidgets('reset clears every group', (tester) async {
    ExploreFilterSelection? result;
    await openSheet(
      tester,
      onResult: (value) => result = value,
      category: 'penyu',
      distance: DistanceBand.jauh,
      condition: ProjectCondition.kritis,
    );

    await tester.tap(find.text('Atur ulang'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.category, 'semua');
    expect(result!.distance, DistanceBand.semua);
    expect(result!.condition, isNull);
  });

  testWidgets('active filter count ignores the default "Semua" values', (
    tester,
  ) async {
    expect(
      const ExploreFilterSelection(
        category: 'semua',
        distance: DistanceBand.semua,
      ).activeCount,
      0,
    );
    expect(
      const ExploreFilterSelection(
        category: 'penyu',
        distance: DistanceBand.semua,
      ).activeCount,
      1,
    );
    expect(
      const ExploreFilterSelection(
        category: 'penyu',
        distance: DistanceBand.jauh,
        condition: ProjectCondition.kritis,
      ).activeCount,
      3,
    );
  });

  testWidgets('the debug switch flips the app-wide offline state', (
    tester,
  ) async {
    addTearDown(() => OfflineController.instance.setOffline(false));
    await openSheet(tester, onResult: (_) {});
    expect(OfflineController.instance.offline, isFalse);

    await tester.tap(find.text('Simulasikan offline'));
    await tester.pump();

    expect(OfflineController.instance.offline, isTrue);
  });
}
