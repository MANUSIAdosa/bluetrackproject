import 'package:blue_track/features/explore/domain/explore_map_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('fromJson reads the user location, the conditions and the areas', () {
    final data = ExploreMapData.fromJson({
      'userLocation': {'latitude': -6.2, 'longitude': 106.8, 'label': 'Jakarta'},
      'conditions': {'p01': 'kritis', 'p02': 'pemantauan'},
      'conservationAreas': [
        {
          'id': 'a01',
          'name': 'Kawasan Konservasi Raja Ampat',
          'status': 'kritis',
          'points': [
            [-0.5, 130.0],
            [-0.5, 131.0],
            [-1.0, 131.0],
          ],
        },
      ],
    });

    expect(data.userLocation, const LatLng(-6.2, 106.8));
    expect(data.userLocationLabel, 'Jakarta');
    expect(data.conditionOf('p01'), ProjectCondition.kritis);
    expect(data.conditionOf('p02'), ProjectCondition.pemantauan);
    expect(data.conservationAreas, hasLength(1));
    expect(
      data.conservationAreas.single.name,
      'Kawasan Konservasi Raja Ampat',
    );
    expect(data.conservationAreas.single.points, hasLength(3));
  });

  test('conditionOf returns null for a project without condition data', () {
    final data = ExploreMapData.fromJson({
      'userLocation': {'latitude': -6.2, 'longitude': 106.8},
      'conditions': <String, dynamic>{},
      'conservationAreas': <dynamic>[],
    });

    expect(data.conditionOf('p09'), isNull);
  });

  test('distanceKm matches the great-circle distance between two points', () {
    // Jakarta → Bandung is roughly 120 km.
    final km = distanceKm(
      const LatLng(-6.2, 106.816666),
      const LatLng(-6.917464, 107.619123),
    );

    expect(km, closeTo(120, 5));
  });

  test('distance bands split the projects by distance to the user', () {
    expect(DistanceBand.semua.matches(1), isTrue);
    expect(DistanceBand.semua.matches(5000), isTrue);
    expect(DistanceBand.dekat.matches(120), isTrue);
    expect(DistanceBand.dekat.matches(250), isFalse);
    expect(DistanceBand.sedang.matches(250), isTrue);
    expect(DistanceBand.sedang.matches(1000), isTrue);
    expect(DistanceBand.sedang.matches(120), isFalse);
    expect(DistanceBand.jauh.matches(1000), isFalse);
    expect(DistanceBand.jauh.matches(1200), isTrue);
  });
}
