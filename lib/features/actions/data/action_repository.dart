import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/action_item.dart';

/// Data source for the Action Agenda.
///
/// A real API implementation can replace [MockActionRepository] later without
/// the page, cards, or detail page changing.
abstract interface class ActionRepository {
  Future<List<ActionItem>> getActions();

  /// Detail lookup for `/actions/:id`. Returns null when the id is unknown.
  Future<ActionItem?> getActionById(String id);

  /// Simulated registration. The page persists the local participation flag
  /// after this call succeeds; a real API would create the registration here.
  Future<void> registerAction(String id);
}

/// Reads `assets/mock/actions.json`.
class MockActionRepository implements ActionRepository {
  const MockActionRepository({
    this.delay = const Duration(milliseconds: 300),
    this.simulateFailure = false,
    this.simulateRegistrationFailure = false,
  });

  /// Simulated request latency so the skeleton is visible in the demo.
  final Duration delay;

  /// Test/demo switch that forces the load/error state.
  final bool simulateFailure;

  /// Test/demo switch that forces the registration failure path.
  final bool simulateRegistrationFailure;

  static const _asset = 'assets/mock/actions.json';

  @override
  Future<List<ActionItem>> getActions() async {
    final actions = await _loadAll();
    actions.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return actions;
  }

  @override
  Future<ActionItem?> getActionById(String id) async {
    final actions = await _loadAll();
    for (final action in actions) {
      if (action.id == id) return action;
    }
    return null;
  }

  @override
  Future<void> registerAction(String id) async {
    await _wait();
    if (simulateFailure || simulateRegistrationFailure) {
      throw StateError('Simulated action-registration failure');
    }
  }

  Future<List<ActionItem>> _loadAll() async {
    await _wait();
    if (simulateFailure) {
      throw StateError('Simulated action-load failure');
    }

    final raw = await rootBundle.loadString(_asset);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((item) => ActionItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }
}
