import 'dart:convert';
import 'dart:io';

import 'package:blue_track/features/explore/domain/project.dart';
import 'package:blue_track/features/organization/domain/organization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projects.json parses into domain models', () {
    final raw = File('assets/mock/projects.json').readAsStringSync();
    final list = jsonDecode(raw) as List<dynamic>;
    final projects = list
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();

    expect(projects, isNotEmpty);
    for (final project in projects) {
      expect(project.id, isNotEmpty);
      expect(project.title, isNotEmpty);
      expect(project.targetAmount, greaterThan(0));
      expect(project.progress, inInclusiveRange(0, 1));
      expect(project.budget, isNotEmpty);
      expect(project.galleryColors, isNotEmpty);
    }

    // Category filter behavior used by Explore.
    final categories = projects.map((p) => p.category).toSet();
    expect(categories.length, greaterThan(1));
  });

  test('organizations.json parses into domain models', () {
    final raw = File('assets/mock/organizations.json').readAsStringSync();
    final list = jsonDecode(raw) as List<dynamic>;
    final orgs =
        list.map((e) => Organization.fromJson(e as Map<String, dynamic>)).toList();

    expect(orgs, isNotEmpty);
    for (final org in orgs) {
      expect(org.id, isNotEmpty);
      expect(org.name, isNotEmpty);
      expect(org.checklist, isNotEmpty);
    }
  });

  test('filters.json exposes the static Explore categories', () {
    final raw = File('assets/mock/filters.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final categories = (decoded['categories'] as List<dynamic>).cast<String>();

    expect(categories, contains('semua'));
    expect(categories.length, greaterThan(2));
  });
}
