import 'dart:typed_data';

import 'package:blue_track/features/explore/domain/explore_map_data.dart';
import 'package:blue_track/features/explore/domain/project.dart';
import 'package:blue_track/features/explore/presentation/widgets/explore_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'support/test_harness.dart';

/// One pixel of transparent PNG — keeps the tile layer off the network.
final _transparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentPng);
}

Project _project({
  required String id,
  required String title,
  String category = 'penyu',
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
  galleryColors: const ['#0EA5E9'],
);

final _projects = [
  _project(id: 'p01', title: 'Peneluruhan Penyu', latitude: -6.18),
  _project(
    id: 'p02',
    title: 'Pemulihan Karang',
    category: 'karang',
    latitude: -6.22,
    longitude: 106.82,
  ),
];

const _mapData = ExploreMapData(
  userLocation: LatLng(-6.2, 106.816666),
  conditions: {'p01': ProjectCondition.baik, 'p02': ProjectCondition.kritis},
  conservationAreas: [
    ConservationArea(
      id: 'a01',
      name: 'Kawasan Konservasi Uji',
      status: ProjectCondition.pemantauan,
      points: [
        LatLng(-6.3, 106.7),
        LatLng(-6.3, 106.9),
        LatLng(-6.1, 106.9),
      ],
    ),
  ],
);

Future<void> pumpMap(
  WidgetTester tester, {
  bool showConservationLayer = false,
  bool offline = false,
  void Function(String projectId)? onOpenProject,
}) async {
  await tester.pumpWidget(
    wrapPage(
      ExploreMap(
        projects: _projects,
        mapData: _mapData,
        userLocationLabel: 'Jakarta',
        showConservationLayer: showConservationLayer,
        offline: offline,
        tileProvider: _FakeTileProvider(),
        initialZoom: 8,
        onOpenProject: onOpenProject,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders one marker per project', (tester) async {
    await pumpMap(tester);

    expect(find.byKey(const ValueKey('explore.marker.p01')), findsOneWidget);
    expect(find.byKey(const ValueKey('explore.marker.p02')), findsOneWidget);
  });

  testWidgets('the conservation layer only draws when it is switched on', (
    tester,
  ) async {
    await pumpMap(tester);
    expect(find.byKey(const ValueKey('explore.conservationLayer')), findsNothing);

    await pumpMap(tester, showConservationLayer: true);
    expect(
      find.byKey(const ValueKey('explore.conservationLayer')),
      findsOneWidget,
    );
  });

  testWidgets('marks the project count on the map', (tester) async {
    await pumpMap(tester);

    expect(find.text('2 proyek di peta'), findsOneWidget);
  });

  testWidgets('tapping a marker opens the project preview sheet', (
    tester,
  ) async {
    String? opened;
    await pumpMap(tester, onOpenProject: (id) => opened = id);

    await tester.tap(find.byKey(const ValueKey('explore.marker.p02')));
    await tester.pumpAndSettle();

    expect(find.text('Pemulihan Karang'), findsWidgets);
    expect(find.textContaining('Kritis'), findsOneWidget);

    await tester.tap(find.text('Lihat proyek'));
    await tester.pumpAndSettle();

    expect(opened, 'p02');
  });

  testWidgets('offline skips the network tiles but keeps the markers', (
    tester,
  ) async {
    await pumpMap(tester, offline: true);

    expect(find.byType(TileLayer), findsNothing);
    expect(find.byKey(const ValueKey('explore.marker.p01')), findsOneWidget);
  });

  testWidgets('online draws the tile layer', (tester) async {
    await pumpMap(tester);

    expect(find.byType(TileLayer), findsOneWidget);
  });
}
