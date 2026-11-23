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

  /// Cancels the current user's registration for [id].
  ///
  /// A real API would delete the registration and return the updated
  /// participant count; the mock mirrors that with a session-only delta.
  Future<void> cancelRegistration(String id);
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

  /// Registrations created minus cancellations in this session.
  ///
  /// `actions.json` holds the starting participant count and is never written
  /// back, so the mock keeps the delta in memory to behave like the API would
  /// (the count moves after a successful registration). TODO(aksi): delete
  /// together with the mock repository once the API returns the live count.
  static final Map<String, int> _sessionDeltas = {};

  /// Test hook: forget this session's deltas.
  static void resetSessionState() => _sessionDeltas.clear();

  @override
  Future<List<ActionItem>> getActions() async {
    final actions = await _loadAll();
    actions.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return [for (final action in actions) _withSessionCount(action)];
  }

  @override
  Future<ActionItem?> getActionById(String id) async {
    final actions = await _loadAll();
    for (final action in actions) {
      if (action.id == id) return _withSessionCount(action);
    }
    return null;
  }

  @override
  Future<void> registerAction(String id) async {
    await _wait();
    if (simulateFailure || simulateRegistrationFailure) {
      throw StateError('Simulated action-registration failure');
    }
    _sessionDeltas[id] = (_sessionDeltas[id] ?? 0) + 1;
  }

  @override
  Future<void> cancelRegistration(String id) async {
    await _wait();
    if (simulateFailure || simulateRegistrationFailure) {
      throw StateError('Simulated action-cancellation failure');
    }
    // Only release a seat this session added: the demo seed already counts its
    // own participants, so cancelling one of those must not invent a drop.
    final delta = _sessionDeltas[id] ?? 0;
    if (delta > 0) _sessionDeltas[id] = delta - 1;
  }

  /// Applies this session's delta without ever leaving the 0..quota range.
  ActionItem _withSessionCount(ActionItem item) {
    final delta = _sessionDeltas[item.id] ?? 0;
    if (delta == 0) return item;
    return item.copyWith(
      registered: (item.registered + delta).clamp(0, item.quota),
    );
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
