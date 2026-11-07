import 'dart:io';

import 'package:blue_track/core/config/app_config.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/explore/domain/project.dart';
import 'package:blue_track/features/explore/presentation/explore_page.dart';
import 'package:blue_track/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_harness.dart';

List<Project> _projects() => [
  buildProject(id: 'p01', title: 'Penyu Hijau', category: 'penyu'),
  buildProject(id: 'p02', title: 'Karang Razak', category: 'karang'),
];

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double scale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapPage(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: ExplorePage(
          projectRepository: FakeProjectRepository(_projects()),
          filterRepository: FakeFilterRepository(const [
            'semua',
            'penyu',
            'karang',
            'mangrove',
            'mamalia_laut',
            'lamun',
          ]),
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

late Directory _dir;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _dir = await Directory.systemTemp.createTemp('bt_empty');
    Hive.init(_dir.path);
    await Hive.openBox<dynamic>(AppConfig.savedProjectsBox);
    final box = Hive.box<dynamic>(AppConfig.savedProjectsBox);
    await box.putAll({'p01': true, 'p02': true});
    await SavedProjectsController.instance.load();
  });

  tearDown(() async {
    await Hive.close();
    await _dir.delete(recursive: true);
  });

  for (final scale in const [1.5, 2.0]) {
    testWidgets('search empty $scale', (tester) async {
      await _pump(tester, size: const Size(320, 568), scale: scale);
      await tester.enterText(find.byType(TextField), 'tidak ada');
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(EmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Atur ulang filter'), warnIfMissed: false);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('saved miss $scale', (tester) async {
      await _pump(tester, size: const Size(320, 568), scale: scale);
      await tester.tap(find.byKey(const ValueKey('explore.scope.saved')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.enterText(find.byType(TextField), 'mamalia');
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(EmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
