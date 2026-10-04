import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/organization.dart';

/// Data source contract for organizations (P05).
abstract interface class OrganizationRepository {
  Future<Organization?> getById(String id);
}

/// Mock implementation reading `assets/mock/organizations.json`.
class MockOrganizationRepository implements OrganizationRepository {
  const MockOrganizationRepository();

  static const _asset = 'assets/mock/organizations.json';

  @override
  Future<Organization?> getById(String id) async {
    final raw = await rootBundle.loadString(_asset);
    final list = jsonDecode(raw) as List<dynamic>;
    for (final item in list) {
      final org = Organization.fromJson(item as Map<String, dynamic>);
      if (org.id == id) return org;
    }
    return null;
  }
}
