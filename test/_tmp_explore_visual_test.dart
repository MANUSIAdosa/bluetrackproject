import 'dart:io';

import 'package:blue_track/features/explore/data/explore_map_repository.dart';
import 'package:blue_track/features/explore/data/project_repository.dart';
import 'package:blue_track/features/explore/domain/explore_map_data.dart';
import 'package:blue_track/features/explore/domain/project.dart';
import 'package:blue_track/features/explore/presentation/explore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_track/core/config/app_config.dart';

import 'support/test_harness.dart';

late List<Project> _projects;
late List<String> _categories;
late ExploreMapData _mapData;

class _FakeMapRepository implements ExploreMapRepository {
  @override
  Future<ExploreMapData> getMapData() async => _mapData;
}

Future<void> _loadRealData(WidgetTester tester) async {
  await tester.runAsync(() async {
    _projects = await const MockProjectRepository().getProjects();
    _categories = await const MockFilterRepository().getCategoryIds();
    _mapData = await const MockExploreMapRepository().getMapData();
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  double scale = 1,
  bool precache = true,
}) async {
  SharedPreferences.setMockInitialValues({
    'selected_interests': ['penyu', 'karang'],
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapPage(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: ExplorePage(
          projectRepository: FakeProjectRepository(_projects),
          filterRepository: FakeFilterRepository(_categories),
          mapRepository: _FakeMapRepository(),
        ),
      ),
    ),
  );
  // The localization delegate resolves on the next frame, so the page is only
  // in the tree after one more pump.
  await tester.pump();
  // Decode the category artwork so the golden shows the real PNGs, not the
  // Material fallback that widget tests render before an image frame exists.
  // Map mode skips this: real async lets flutter_map initialise an on-disk
  // tile cache, which has no path_provider implementation in tests.
  if (precache) {
    final context = tester.element(find.byType(ExplorePage));
    await tester.runAsync(() async {
      for (final id in [
        'penyu',
        'karang',
        'mangrove',
        'mamalia_laut',
        'lamun',
      ]) {
        await precacheImage(
          AssetImage('assets/icons/categories/$id.png'),
          context,
        );
      }
    });
  }
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

late Directory _hiveDir;

void main() {
  setUp(() async {
    _hiveDir = await Directory.systemTemp.createTemp('bt_vis');
    Hive.init(_hiveDir.path);
    await Hive.openBox<dynamic>(AppConfig.savedProjectsBox);
  });

  tearDown(() async {
    await Hive.close();
    await _hiveDir.delete(recursive: true);
  });

  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File(
          '/Users/richie/Documents/fluttersdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await icons.load();
  });

  testWidgets('explore list top', (tester) async {
    await _loadRealData(tester);
    await _pump(tester, size: const Size(390, 844));
    await expectLater(
      find.byType(ExplorePage),
      matchesGoldenFile('goldens/_tmp_explore_top.png'),
    );
  });

  testWidgets('explore list scrolled', (tester) async {
    await _loadRealData(tester);
    await _pump(tester, size: const Size(390, 844));
    await tester.drag(
      find.byKey(const ValueKey('explore.projectList')),
      const Offset(0, -760),
    );
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byType(ExplorePage),
      matchesGoldenFile('goldens/_tmp_explore_scrolled.png'),
    );
  });

  testWidgets('explore empty search', (tester) async {
    await _loadRealData(tester);
    await _pump(tester, size: const Size(390, 844));
    await tester.enterText(find.byType(TextField), 'tidak ada hasil');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(
      find.byType(ExplorePage),
      matchesGoldenFile('goldens/_tmp_explore_empty.png'),
    );
  });

  testWidgets('explore empty search narrow large text', (tester) async {
    await _loadRealData(tester);
    await _pump(tester, size: const Size(360, 640), scale: 1.3);
    await tester.enterText(find.byType(TextField), 'tidak ada hasil');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ExplorePage),
      matchesGoldenFile('goldens/_tmp_explore_empty_narrow.png'),
    );
  });

  testWidgets('explore saved scope empty', (tester) async {
    await _loadRealData(tester);
    await _pump(tester, size: const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('explore.scope.saved')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(
      find.byType(ExplorePage),
      matchesGoldenFile('goldens/_tmp_explore_saved_empty.png'),
    );
  });

  testWidgets('explore large text', (tester) async {
    await _loadRealData(tester);
    await _pump(tester, size: const Size(390, 844), scale: 2.0);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ExplorePage),
      matchesGoldenFile('goldens/_tmp_explore_large_text.png'),
    );
  });

  testWidgets('explore category rail end', (tester) async {
    await _loadRealData(tester);
    await _pump(tester, size: const Size(390, 844));
    await tester.drag(
      find.byKey(const ValueKey('explore.category.semua')),
      const Offset(-400, 0),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ExplorePage),
      matchesGoldenFile('goldens/_tmp_explore_rail_end.png'),
    );
  });

  testWidgets('explore map mode', (tester) async {
    // flutter_map's built-in tile cache asks path_provider for a directory.
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => Directory.systemTemp.path,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await _loadRealData(tester);
    await _pump(tester, size: const Size(390, 844), precache: false);
    await tester.tap(find.byKey(const ValueKey('explore.view.map')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(
      find.byType(ExplorePage),
      matchesGoldenFile('goldens/_tmp_explore_map_after.png'),
    );
  });

  testWidgets('explore for you mid scroll', (tester) async {
    await _loadRealData(tester);
    await _pump(tester, size: const Size(390, 844));
    await tester.drag(
      find.byKey(const ValueKey('explore.forYouRail')),
      const Offset(-120, 0),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byType(ExplorePage),
      matchesGoldenFile('goldens/_tmp_explore_rail_mid.png'),
    );
  });

  testWidgets('explore tablet', (tester) async {
    await _loadRealData(tester);
    await _pump(tester, size: const Size(800, 1000));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ExplorePage),
      matchesGoldenFile('goldens/_tmp_explore_tablet.png'),
    );
  });
}
