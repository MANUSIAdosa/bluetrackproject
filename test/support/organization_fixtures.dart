import 'dart:convert';
import 'dart:io';

import 'package:blue_track/features/explore/domain/project.dart';
import 'package:blue_track/features/organization/data/organization_repository.dart';
import 'package:blue_track/features/organization/domain/organization.dart';

/// Parses the bundled organization mock from disk once.
///
/// Widget tests cannot reliably await `rootBundle` after the first test in the
/// same file on Windows, so read the same JSON synchronously instead.
List<Organization>? _organizationsCache;

List<Organization> mockOrganizations() {
  final cached = _organizationsCache;
  if (cached != null) return cached;

  final raw = File('assets/mock/organizations.json').readAsStringSync();
  final decoded = jsonDecode(raw) as List<dynamic>;
  return _organizationsCache = decoded
      .map((item) => Organization.fromJson(item as Map<String, dynamic>))
      .toList(growable: false);
}

Organization mockOrganization(String id) =>
    mockOrganizations().firstWhere((organization) => organization.id == id);

/// Raw JSON object for one organization, useful for tests that need a variant
/// (for example an extra unavailable managed location) without editing the
/// shared mock file.
Map<String, dynamic> mockOrganizationJson(String id) {
  final raw = File('assets/mock/organizations.json').readAsStringSync();
  final decoded = jsonDecode(raw) as List<dynamic>;
  for (final item in decoded) {
    final map = item as Map<String, dynamic>;
    if (map['id'] == id) return Map<String, dynamic>.of(map);
  }
  throw StateError('Unknown organization: $id');
}

/// Parses the bundled project mock from disk once.
List<Project>? _projectsCache;

List<Project> mockProjects() {
  final cached = _projectsCache;
  if (cached != null) return cached;

  final raw = File('assets/mock/projects.json').readAsStringSync();
  final decoded = jsonDecode(raw) as List<dynamic>;
  return _projectsCache = decoded
      .map((item) => Project.fromJson(item as Map<String, dynamic>))
      .toList(growable: false);
}

/// In-memory [OrganizationRepository] backed by the real mock fixtures.
class InMemoryOrganizationRepository implements OrganizationRepository {
  InMemoryOrganizationRepository([List<Organization>? organizations])
    : _organizations = List<Organization>.of(
        organizations ?? mockOrganizations(),
      );

  final List<Organization> _organizations;

  /// When true every call throws, so the error state can be exercised.
  bool shouldFail = false;

  int callCount = 0;

  @override
  Future<Organization?> getById(String id) async {
    callCount++;
    if (shouldFail) throw Exception('Simulated organization failure');
    for (final organization in _organizations) {
      if (organization.id == id) return organization;
    }
    return null;
  }
}
