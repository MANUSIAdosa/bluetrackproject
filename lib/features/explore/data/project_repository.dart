import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/project.dart';

/// Data source contract — swap with an API implementation later without
/// touching the UI.
abstract interface class ProjectRepository {
  Future<List<Project>> getProjects({String? category});
  Future<Project?> getProjectById(String id);

  /// Projects belonging to one organization (P05 profile).
  Future<List<Project>> getProjectsByOrgId(String orgId);
}

/// Mock implementation reading `assets/mock/projects.json`.
class MockProjectRepository implements ProjectRepository {
  const MockProjectRepository();

  static const _asset = 'assets/mock/projects.json';

  Future<List<Project>> _load() async {
    final raw = await rootBundle.loadString(_asset);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Project>> getProjects({String? category}) async {
    final projects = await _load();
    if (category == null || category == 'semua') return projects;
    return projects.where((p) => p.category == category).toList();
  }

  @override
  Future<Project?> getProjectById(String id) async {
    final projects = await _load();
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  @override
  Future<List<Project>> getProjectsByOrgId(String orgId) async {
    final projects = await _load();
    return projects.where((p) => p.orgId == orgId).toList();
  }
}

/// Static Explore filters from `assets/mock/filters.json`.
abstract interface class FilterRepository {
  Future<List<String>> getCategoryIds();
}

class MockFilterRepository implements FilterRepository {
  const MockFilterRepository();

  @override
  Future<List<String>> getCategoryIds() async {
    final raw = await rootBundle.loadString('assets/mock/filters.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['categories'] as List<dynamic>).cast<String>();
  }
}
