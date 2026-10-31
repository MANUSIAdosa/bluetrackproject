import 'dart:async';
import 'dart:io';

import 'package:blue_track/core/config/app_config.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/explore/data/explore_map_repository.dart';
import 'package:blue_track/features/explore/data/saved_project_store.dart';
import 'package:blue_track/features/explore/domain/explore_map_data.dart';
import 'package:blue_track/features/explore/domain/project.dart';
import 'package:blue_track/features/explore/presentation/explore_page.dart';
import 'package:blue_track/features/explore/presentation/widgets/explore_header.dart';
import 'package:blue_track/shared/widgets/empty_state.dart';
import 'package:blue_track/shared/widgets/project_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_harness.dart';

/// Projects near Jakarta, so the map can draw them without panning.
Project _project({
  required String id,
  required String title,
  required String category,
  double latitude = -6.2,
  double longitude = 106.8,
}) => Project(
  id: id,
  title: title,
  category: category,
  orgId: 'o01',
  orgName: 'Yayasan Laut Biru',
  orgVerified: true,
  location: 'Jakarta',
  latitude: latitude,
  longitude: longitude,
  raisedAmount: 1000,
  targetAmount: 2000,
  description: 'Deskripsi',
  about: const ['Tentang'],
  budget: const [BudgetLine(item: 'Patroli', amount: 1000, percent: 100)],
  galleryColors: const ['#0EA5E9', '#14B8A6'],
);

class FakeExploreMapRepository implements ExploreMapRepository {
  FakeExploreMapRepository(this.data);

  final ExploreMapData data;

  @override
  Future<ExploreMapData> getMapData() async => data;
}

final _mapData = ExploreMapData(
  userLocation: const LatLng(-6.2, 106.816666),
  userLocationLabel: 'Jakarta',
  conditions: const {'p01': ProjectCondition.baik, 'p02': ProjectCondition.kritis},
  conservationAreas: const [
    ConservationArea(
      id: 'a01',
      name: 'Kawasan Konservasi Uji',
      status: ProjectCondition.pemantauan,
      points: [LatLng(-6.3, 106.7), LatLng(-6.3, 106.9), LatLng(-6.1, 106.9)],
    ),
  ],
);

List<Project> _twoProjects() => [
  _project(id: 'p01', title: 'Peneluruhan Penyu', category: 'penyu'),
  _project(
    id: 'p02',
    title: 'Pemulihan Karang',
    category: 'karang',
    latitude: -6.22,
  ),
];

late Directory _hiveDir;

Future<void> pumpExplore(
  WidgetTester tester, {
  required FakeProjectRepository projects,
}) async {
  await tester.pumpWidget(
    wrapPage(
      ExplorePage(
        projectRepository: projects,
        filterRepository: FakeFilterRepository([
          'semua',
          'penyu',
          'karang',
        ]),
        mapRepository: FakeExploreMapRepository(_mapData),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapSheetOption(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> openFilterSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('explore.filterButton')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      AppConfig.interestsKey: ['mamalia_laut'],
    });
    _hiveDir = await Directory.systemTemp.createTemp('bluetrack_explore_map');
    Hive.init(_hiveDir.path);
    await Hive.openBox<dynamic>(AppConfig.savedProjectsBox);
    // Opened here on purpose: `Hive.openBox` reads files, and file I/O never
    // completes inside the fake-async zone a `testWidgets` body runs in. With
    // the box already open, the page's offline read resolves in a microtask.
    await Hive.openBox<dynamic>(SavedProjectStore.boxName);
    await SavedProjectsController.instance.load();
    OfflineController.instance.setOffline(false);
  });

  tearDown(() async {
    OfflineController.instance.setOffline(false);
    await Hive.close();
    if (_hiveDir.existsSync()) _hiveDir.deleteSync(recursive: true);
  });

  testWidgets('the list/map toggle switches the body without losing filters', (
    tester,
  ) async {
    await pumpExplore(tester, projects: FakeProjectRepository(_twoProjects()));
    expect(find.byType(ProjectCard), findsAtLeastNWidgets(1));

    await tapKey(tester, 'explore.view.map');

    expect(find.byKey(const ValueKey('explore.marker.p01')), findsOneWidget);
    expect(find.byType(ProjectCard), findsNothing);

    await tapKey(tester, 'explore.view.list');

    expect(find.byType(ProjectCard), findsAtLeastNWidgets(1));
  });

  testWidgets('map mode hides the category rail so the map gets the space', (
    tester,
  ) async {
    await pumpExplore(tester, projects: FakeProjectRepository(_twoProjects()));
    expect(find.byType(CategorySelector), findsOneWidget);

    await tapKey(tester, 'explore.view.map');

    expect(find.byType(CategorySelector), findsNothing);
    expect(find.byKey(const ValueKey('explore.marker.p01')), findsOneWidget);
  });

  testWidgets('the condition filter narrows the map markers as well', (
    tester,
  ) async {
    await pumpExplore(tester, projects: FakeProjectRepository(_twoProjects()));
    await tapKey(tester, 'explore.view.map');
    expect(find.byKey(const ValueKey('explore.marker.p02')), findsOneWidget);

    await openFilterSheet(tester);
    await tapSheetOption(tester, 'explore.filter.condition.kritis');
    await tester.tap(find.byKey(const ValueKey('explore.filter.apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('explore.marker.p02')), findsOneWidget);
    expect(find.byKey(const ValueKey('explore.marker.p01')), findsNothing);
  });

  testWidgets('the conservation layer is a toggle on the map', (tester) async {
    await pumpExplore(tester, projects: FakeProjectRepository(_twoProjects()));
    await tapKey(tester, 'explore.view.map');

    expect(find.byKey(const ValueKey('explore.conservationLayer')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('explore.conservationSwitch')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('explore.conservationLayer')),
      findsOneWidget,
    );
  });

  testWidgets('filter button badges how many groups are active', (tester) async {
    await pumpExplore(tester, projects: FakeProjectRepository(_twoProjects()));
    expect(find.byKey(const ValueKey('explore.filterCount')), findsNothing);

    await openFilterSheet(tester);
    await tapSheetOption(tester, 'explore.filter.distance.dekat');
    await tester.tap(find.byKey(const ValueKey('explore.filter.apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('explore.filterCount')), findsOneWidget);
  });

  testWidgets('offline reads the saved snapshots instead of the repository', (
    tester,
  ) async {
    final projects = FakeProjectRepository(_twoProjects());
    await tester.runAsync(() async {
      await toggleSavedProject(_twoProjects().first);
    });
    OfflineController.instance.setOffline(true);

    await pumpExplore(tester, projects: projects);

    // The banner itself lives in AppShell (P00), above every tab; Explore's job
    // is to render the saved snapshots and to skip the repository entirely.
    expect(find.text('Peneluruhan Penyu'), findsOneWidget);
    expect(find.text('Pemulihan Karang'), findsNothing);
    expect(projects.callCount, 0, reason: 'no repository call while offline');
  });

  testWidgets('offline without saved projects points at the bookmark', (
    tester,
  ) async {
    final projects = FakeProjectRepository(_twoProjects());
    OfflineController.instance.setOffline(true);

    await pumpExplore(tester, projects: projects);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Belum ada proyek tersimpan'), findsOneWidget);
  });

  testWidgets('opening the filter while the map data is still loading waits '
      'for the reference location', (tester) async {
    final completer = Completer<ExploreMapData>();
    await tester.pumpWidget(
      wrapPage(
        ExplorePage(
          projectRepository: FakeProjectRepository(_twoProjects()),
          filterRepository: FakeFilterRepository(['semua', 'penyu', 'karang']),
          mapRepository: _DelayedMapRepository(completer.future),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tapKey(tester, 'explore.view.map');
    await tester.tap(find.byKey(const ValueKey('explore.filterButton')));
    await tester.pump();
    completer.complete(_mapData);
    await tester.pumpAndSettle();

    expect(find.textContaining('Jakarta'), findsOneWidget);
  });
}

/// Map repository whose read the test completes by hand.
class _DelayedMapRepository implements ExploreMapRepository {
  _DelayedMapRepository(this.future);

  final Future<ExploreMapData> future;

  @override
  Future<ExploreMapData> getMapData() => future;
}
