import 'dart:io';

import 'package:blue_track/core/config/app_config.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/explore/data/saved_project_store.dart';
import 'package:blue_track/features/explore/domain/project.dart';
import 'package:blue_track/shared/widgets/project_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'support/test_harness.dart';

late Directory _hiveDir;

/// Bookmark button of the card (the icon button over the gallery placeholder).
Finder bookmarkButton() => find.descendant(
  of: find.byType(ProjectCard),
  matching: find.byType(IconButton),
);

void main() {
  setUp(() async {
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
    await tester.pumpWidget(wrapPage(phoneSized(ProjectCard(project: project))));
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

    await tester.pumpWidget(wrapPage(phoneSized(ProjectCard(project: project))));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Karang Razak'), findsOneWidget);
  });
}
