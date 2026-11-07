import 'dart:io';

import 'package:blue_track/core/config/app_config.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/explore/data/saved_project_store.dart';
import 'package:blue_track/features/explore/domain/project.dart';
import 'package:blue_track/features/explore/presentation/explore_page.dart';
import 'package:blue_track/features/project/presentation/project_detail_page.dart';
import 'package:blue_track/shared/widgets/project_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_harness.dart';

late Directory _hiveDir;

/// Bookmark button of the card (the icon button over the gallery placeholder).
Finder bookmarkButton() => find.descendant(
  of: find.byType(ProjectCard),
  matching: find.byType(IconButton),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _hiveDir = await Directory.systemTemp.createTemp('bluetrack_card_save');
    Hive.init(_hiveDir.path);
    await Hive.openBox<dynamic>(AppConfig.savedProjectsBox);
    await Hive.openBox<dynamic>(SavedProjectStore.boxName);
    await SavedProjectsController.instance.load();
  });

  tearDown(() async {
    await Hive.close();
    if (_hiveDir.existsSync()) _hiveDir.deleteSync(recursive: true);
  });

  testWidgets('bookmarking a card also writes the offline snapshot', (
    tester,
  ) async {
    final project = buildProject(id: 'p01', title: 'Penyu Hijau');
    await tester.pumpWidget(
      wrapPage(phoneSized(ProjectCard(project: project))),
    );
    await tester.pump();

    // Saving touches Hive files, so the tap and the write have to run outside
    // the fake-async zone of the test body.
    await tester.runAsync(() async {
      await tester.tap(bookmarkButton());
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    expect(SavedProjectsController.instance.isSaved('p01'), isTrue);
    final stored = await tester.runAsync(
      () => SavedProjectStore.instance.loadAll(),
    );
    expect(stored!.map((p) => p.id), ['p01']);
  });

  testWidgets('saving from the detail page reaches the offline saved list', (
    tester,
  ) async {
    final project = buildProject(id: 'p01', title: 'Penyu Hijau');
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapPage(
        ProjectDetailPage(
          projectId: 'p01',
          projectRepository: FakeProjectRepository([project]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The app-bar bookmark is the only entry point on the detail page.
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.bookmark_outline));
      await tester.pump();
      // The write to Hive completes on the real event loop; the rebuild that
      // flips the icon needs one more frame afterwards.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(SavedProjectsController.instance.isSaved('p01'), isTrue);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);

    OfflineController.instance.setOffline(true);
    final online = FakeProjectRepository([project]);
    await tester.pumpWidget(
      wrapPage(
        ExplorePage(
          projectRepository: online,
          filterRepository: FakeFilterRepository(['semua', 'penyu']),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Penyu Hijau'), findsOneWidget);
    expect(online.callCount, 0, reason: 'offline never queries the repository');
  });

  testWidgets('a gallery with a single colour still renders', (tester) async {
    final project = Project(
      id: 'p02',
      title: 'Karang Razak',
      category: 'karang',
      orgId: 'o01',
      orgName: 'Yayasan Laut Biru',
      orgVerified: true,
      location: 'Jakarta',
      latitude: -6.1,
      longitude: 106.8,
      raisedAmount: 1000,
      targetAmount: 2000,
      description: 'Deskripsi',
      about: const ['Tentang'],
      budget: const [BudgetLine(item: 'Patroli', amount: 1000, percent: 100)],
      galleryColors: const ['#0EA5E9'],
    );

    await tester.pumpWidget(
      wrapPage(phoneSized(ProjectCard(project: project))),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Karang Razak'), findsOneWidget);
  });
}
