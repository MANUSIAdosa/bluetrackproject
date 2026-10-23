import 'package:latlong2/latlong.dart';

/// Map-only data for P03, read from `assets/mock/p03_explore.json`.
///
/// Kept out of `projects.json` (owned by P04/P05) on purpose: the map adds
/// condition status, a reference location for the distance filter and the
/// conservation-area layer, none of which the project mock carries.
class ExploreMapData {
  const ExploreMapData({
    required this.userLocation,
    required this.conditions,
    required this.conservationAreas,
    this.userLocationLabel = '',
  });

  /// Mock "my location" used by the distance filter. There is no location
  /// package in the project, so the reference point comes from the mock file.
  final LatLng userLocation;

  /// Human-readable name of [userLocation] ("Jakarta"), shown wherever a
  /// distance is displayed so the number is not unexplained.
  final String userLocationLabel;

  /// Condition per project id. A project without an entry has no data.
  final Map<String, ProjectCondition> conditions;

  final List<ConservationArea> conservationAreas;

  ProjectCondition? conditionOf(String projectId) => conditions[projectId];

  factory ExploreMapData.fromJson(Map<String, dynamic> json) {
    final location = json['userLocation'] as Map<String, dynamic>;
    final conditions = (json['conditions'] as Map<String, dynamic>?) ?? const {};
    final areas = (json['conservationAreas'] as List<dynamic>?) ?? const [];

    return ExploreMapData(
      userLocation: LatLng(
        (location['latitude'] as num).toDouble(),
        (location['longitude'] as num).toDouble(),
      ),
      userLocationLabel: (location['label'] as String?) ?? '',
      conditions: {
        for (final entry in conditions.entries)
          entry.key: ProjectCondition.fromId(entry.value as String),
      },
      conservationAreas: areas
          .map((e) => ConservationArea.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Condition of a project or of a conservation area.
enum ProjectCondition {
  baik('baik'),
  pemantauan('pemantauan'),
  kritis('kritis');

  const ProjectCondition(this.id);

  final String id;

  static ProjectCondition fromId(String id) => ProjectCondition.values
      .firstWhere((c) => c.id == id, orElse: () => ProjectCondition.baik);
}

/// A conservation area drawn as a polygon on the map.
class ConservationArea {
  const ConservationArea({
    required this.id,
    required this.name,
    required this.status,
    required this.points,
  });

  final String id;
  final String name;
  final ProjectCondition status;
  final List<LatLng> points;

  factory ConservationArea.fromJson(Map<String, dynamic> json) =>
      ConservationArea(
        id: json['id'] as String,
        name: json['name'] as String,
        status: ProjectCondition.fromId(json['status'] as String),
        points: (json['points'] as List<dynamic>)
            .map(
              (p) => LatLng(
                ((p as List<dynamic>)[0] as num).toDouble(),
                (p[1] as num).toDouble(),
              ),
            )
            .toList(),
      );
}

/// Distance from the mock user location, split into filter bands.
enum DistanceBand {
  semua,
  dekat,
  sedang,
  jauh;

  /// `<250 km` for [dekat], `250–1000 km` for [sedang], `>1000 km` for [jauh].
  bool matches(double km) => switch (this) {
    DistanceBand.semua => true,
    DistanceBand.dekat => km < 250,
    DistanceBand.sedang => km >= 250 && km <= 1000,
    DistanceBand.jauh => km > 1000,
  };
}

/// Great-circle distance in kilometres (haversine, via latlong2).
double distanceKm(LatLng from, LatLng to) =>
    const Distance().as(LengthUnit.Kilometer, from, to);
