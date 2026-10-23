import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/explore_map_data.dart';

/// Map data contract for P03 — the marker categories, the condition filter and
/// the conservation-area layer. Swap with an API implementation later without
/// touching the map widgets.
abstract interface class ExploreMapRepository {
  Future<ExploreMapData> getMapData();
}

/// Reads `assets/mock/p03_explore.json`.
class MockExploreMapRepository implements ExploreMapRepository {
  const MockExploreMapRepository();

  static const _asset = 'assets/mock/p03_explore.json';

  @override
  Future<ExploreMapData> getMapData() async {
    final raw = await rootBundle.loadString(_asset);
    return ExploreMapData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
