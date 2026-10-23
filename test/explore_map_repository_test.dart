import 'dart:convert';

import 'package:blue_track/features/explore/data/explore_map_repository.dart';
import 'package:blue_track/features/explore/domain/explore_map_data.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every project in the mock data has a condition on the map', () async {
    final raw = await rootBundle.loadString('assets/mock/projects.json');
    final projectIds = (jsonDecode(raw) as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toList();

    final data = await const MockExploreMapRepository().getMapData();

    expect(
      data.conditions.keys,
      containsAll(projectIds),
      reason: 'the condition filter must cover every mock project',
    );
  });

  test('the mock data ships conservation areas with drawable polygons', () async {
    final data = await const MockExploreMapRepository().getMapData();

    expect(data.conservationAreas, hasLength(greaterThanOrEqualTo(3)));
    for (final area in data.conservationAreas) {
      expect(area.name, isNotEmpty);
      expect(
        area.points.length,
        greaterThanOrEqualTo(3),
        reason: '${area.id} needs a polygon, not a line',
      );
    }
  });

  test('every condition and area status uses a known enum value', () async {
    final data = await const MockExploreMapRepository().getMapData();
    final known = ProjectCondition.values.map((c) => c.id).toSet();

    final raw = await rootBundle.loadString('assets/mock/p03_explore.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    expect(
      (decoded['conditions'] as Map<String, dynamic>).values.toSet(),
      everyElement(isIn(known)),
    );
    for (final area in data.conservationAreas) {
      expect(area.status.id, isIn(known));
    }
  });
}
