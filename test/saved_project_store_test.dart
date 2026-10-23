import 'dart:io';

import 'package:blue_track/core/config/app_config.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/explore/data/saved_project_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'support/test_harness.dart';

late Directory _hiveDir;

void main() {
  setUp(() async {
    _hiveDir = await Directory.systemTemp.createTemp('bluetrack_snapshots');
    Hive.init(_hiveDir.path);
    await Hive.openBox<dynamic>(AppConfig.savedProjectsBox);
    await SavedProjectsController.instance.load();
  });

  tearDown(() async {
    await Hive.close();
    if (_hiveDir.existsSync()) _hiveDir.deleteSync(recursive: true);
  });

  test('a saved snapshot survives a reload of the box', () async {
    await SavedProjectStore.instance.save(
      buildProject(id: 'p01', title: 'Penyu Hijau'),
    );

    await Hive.close();

    final loaded = await SavedProjectStore.instance.loadAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'p01');
    expect(loaded.single.title, 'Penyu Hijau');
    expect(loaded.single.progress, closeTo(0.75, 0.001));
  });

  test('removing a snapshot leaves the others in place', () async {
    final store = SavedProjectStore.instance;
    await store.save(buildProject(id: 'p01'));
    await store.save(buildProject(id: 'p02', title: 'Karang Razak'));

    await store.remove('p01');

    final loaded = await store.loadAll();
    expect(loaded.map((p) => p.id), ['p02']);
  });

  test('loadAll is empty before anything is saved', () async {
    expect(await SavedProjectStore.instance.loadAll(), isEmpty);
  });

  test('toggling a project flips the saved id and writes the snapshot', () async {
    final project = buildProject(id: 'p01');

    final saved = await toggleSavedProject(project);

    expect(saved, isTrue);
    expect(SavedProjectsController.instance.isSaved('p01'), isTrue);
    expect((await SavedProjectStore.instance.loadAll()).single.id, 'p01');
  });

  test('toggling twice removes both the id and the snapshot', () async {
    final project = buildProject(id: 'p01');

    await toggleSavedProject(project);
    final saved = await toggleSavedProject(project);

    expect(saved, isFalse);
    expect(SavedProjectsController.instance.isSaved('p01'), isFalse);
    expect(await SavedProjectStore.instance.loadAll(), isEmpty);
  });
}
