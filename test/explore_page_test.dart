import 'package:blue_track/core/config/app_config.dart';
import 'package:blue_track/features/explore/presentation/explore_page.dart';
import 'package:blue_track/shared/widgets/empty_state.dart';
import 'package:blue_track/shared/widgets/error_state.dart';
import 'package:blue_track/shared/widgets/project_card.dart';
import 'package:blue_track/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_harness.dart';

/// The loading skeleton animates forever, so `pumpAndSettle` would time out
/// instead of failing on an assertion. Pump a fixed number of frames instead.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> pumpExplore(
  WidgetTester tester, {
  required FakeProjectRepository projects,
  FakeFilterRepository? filters,
}) async {
  // Full test width (800dp) on purpose: the category rail is a horizontal
  // ListView, so a phone-width surface would scroll "Tersimpan" out of view
  // and lazily dispose the other chips. These tests only assert state, not
  // card layout.
  await tester.pumpWidget(
    wrapPage(
      ExplorePage(
        projectRepository: projects,
        filterRepository: filters ?? FakeFilterRepository(),
      ),
    ),
  );
  await pumpFrames(tester);
}

ChoiceChip chipWithLabel(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label));

Future<void> tapChip(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ChoiceChip, label));
  await pumpFrames(tester);
}

void main() {
  setUp(() {
    // No interest matches the fake projects, so the "Untuk minatmu" rail stays
    // out of the way and card counts are predictable.
    SharedPreferences.setMockInitialValues({
      AppConfig.interestsKey: ['mamalia_laut'],
    });
  });

  testWidgets('load failure shows ErrorState instead of endless skeletons',
      (tester) async {
    final projects = FakeProjectRepository([buildProject()])
      ..shouldFail = true;
    await pumpExplore(tester, projects: projects);

    expect(find.byType(SkeletonCard), findsNothing);
    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('"Coba lagi" reloads the list after a load failure',
      (tester) async {
    final projects = FakeProjectRepository([buildProject()])
      ..shouldFail = true;
    await pumpExplore(tester, projects: projects);
    projects.shouldFail = false;

    await tester.tap(find.text('Coba lagi'));
    await pumpFrames(tester);

    expect(projects.callCount, 2);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.byType(ProjectCard), findsAtLeastNWidgets(1));
  });

  testWidgets('a search with no hits offers "Atur ulang filter" which resets '
      'the query and the category', (tester) async {
    final projects = FakeProjectRepository([
      buildProject(),
      buildProject(
        id: 'p02',
        title: 'Pemulihan Karang Razak',
        category: 'karang',
      ),
    ]);
    await pumpExplore(tester, projects: projects);

    await tapChip(tester, 'Karang');
    await tester.enterText(find.byType(TextField), 'tidak-ada-hasil');
    await pumpFrames(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Tidak ada proyek'), findsOneWidget);
    expect(find.text('Atur ulang filter'), findsOneWidget);

    await tester.tap(find.text('Atur ulang filter'));
    await pumpFrames(tester);

    expect(find.byType(ProjectCard), findsAtLeastNWidgets(1));
    expect(find.byType(EmptyState), findsNothing);
    final search = tester.widget<TextField>(find.byType(TextField));
    expect(search.controller?.text, isEmpty);
    expect(chipWithLabel(tester, 'Semua').selected, isTrue);
  });

  testWidgets('empty "Tersimpan" chip offers "Lihat semua proyek", not a retry',
      (tester) async {
    final projects = FakeProjectRepository([buildProject()]);
    await pumpExplore(tester, projects: projects);

    await tapChip(tester, 'Tersimpan');
    await pumpFrames(tester);

    expect(find.text('Belum ada proyek tersimpan'), findsOneWidget);
    expect(find.text('Lihat semua proyek'), findsOneWidget);
    expect(find.text('Coba lagi'), findsNothing);

    await tester.tap(find.text('Lihat semua proyek'));
    await pumpFrames(tester);

    expect(find.text('Belum ada proyek tersimpan'), findsNothing);
    expect(chipWithLabel(tester, 'Semua').selected, isTrue);
    expect(find.byType(ProjectCard), findsAtLeastNWidgets(1));
  });
}