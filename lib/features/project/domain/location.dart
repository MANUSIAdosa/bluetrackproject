/// A conservation location monitored by a project (P04).
///
/// The [id] is intentionally the same value as the matching project id in
/// `assets/mock/projects.json`, so navigating from Explore to Project Detail
/// keeps working without a translation layer.
class ProjectLocation {
  const ProjectLocation({
    required this.id,
    required this.projectId,
    required this.name,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.habitat,
  });

  /// Location id used by reports and reviews. Matches the P04 project id.
  final String id;

  /// Explicit link to the project shown on P04.
  final String projectId;

  /// Short display name, for example `Pantai Sukamade`.
  final String name;

  /// Administrative region, for example `Banyuwangi, Jawa Timur`.
  final String region;

  /// Location latitude in decimal degrees.
  final double latitude;

  /// Location longitude in decimal degrees.
  final double longitude;

  /// Habitat id: penyu | karang | mangrove | mamalia_laut | lamun.
  final String habitat;

  /// Parses one location object from `assets/mock/locations.json`.
  ///
  /// Throws a [FormatException] when a required key is missing or has the wrong
  /// type.
  factory ProjectLocation.fromJson(Map<String, dynamic> json) =>
      ProjectLocation(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        name: json['name'] as String,
        region: json['region'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        habitat: json['habitat'] as String,
      );

  /// Serializes this location back to the mock JSON shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'name': name,
    'region': region,
    'latitude': latitude,
    'longitude': longitude,
    'habitat': habitat,
  };
}
