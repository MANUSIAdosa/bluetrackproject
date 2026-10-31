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
  int Function(ExploreFilterSelection)? countFor,
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
                countFor: countFor,
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

Future<void> tapOption(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('the sheet groups the filters into labelled dimensions', (
    tester,
  ) async {
    await openSheet(tester, onResult: (_) {});

    expect(find.byKey(const ValueKey('explore.filter.sheet')), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Kategori'), findsOneWidget);
    expect(find.text('Jarak'), findsOneWidget);
    expect(find.text('Status kondisi'), findsOneWidget);
    expect(find.text('Atur ulang'), findsOneWidget);
    expect(find.byKey(const ValueKey('explore.filter.apply')), findsOneWidget);
    // A filter sheet uses radio options, not chips.
    expect(find.byType(ChoiceChip), findsNothing);
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

    await tapOption(tester, 'explore.filter.condition.kritis');
    await tester.tap(find.byKey(const ValueKey('explore.filter.apply')));
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

    await tapOption(tester, 'explore.filter.distance.sedang');
    await tester.tap(find.byKey(const ValueKey('explore.filter.apply')));
    await tester.pumpAndSettle();

    expect(result!.distance, DistanceBand.sedang);
    expect(result!.category, 'karang');
  });

  testWidgets('the footer previews how many projects the draft keeps', (
    tester,
  ) async {
    await openSheet(
      tester,
      onResult: (_) {},
      countFor: (draft) => draft.condition == ProjectCondition.kritis ? 1 : 2,
    );

    expect(find.text('Tampilkan 2 proyek'), findsOneWidget);

    await tapOption(tester, 'explore.filter.condition.kritis');

    expect(find.text('Tampilkan 1 proyek'), findsOneWidget);
  });

  testWidgets('reset clears every group without closing the sheet', (
    tester,
  ) async {
    ExploreFilterSelection? result;
    await openSheet(
      tester,
      onResult: (value) => result = value,
      category: 'penyu',
      distance: DistanceBand.jauh,
      condition: ProjectCondition.kritis,
    );

    await tester.tap(find.byKey(const ValueKey('explore.filter.reset')));
    await tester.pumpAndSettle();

    // The sheet stays open so the user can review the cleared draft.
    expect(find.byKey(const ValueKey('explore.filter.sheet')), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.byKey(const ValueKey('explore.filter.apply')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.category, 'semua');
    expect(result!.distance, DistanceBand.semua);
    expect(result!.condition, isNull);
  });

  testWidgets('the close action dismisses without applying', (tester) async {
    ExploreFilterSelection? result;
    await openSheet(tester, onResult: (value) => result = value);

    await tester.tap(find.byKey(const ValueKey('explore.filter.close')));
    await tester.pumpAndSettle();

    expect(result, isNull);
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

    final switchFinder = find.text('Simulasikan offline');
    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder);
    await tester.pump();

    expect(OfflineController.instance.offline, isTrue);
  });
}
