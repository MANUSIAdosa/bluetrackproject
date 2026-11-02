import 'dart:async';

import 'package:blue_track/features/actions/data/action_participation_store.dart';
import 'package:blue_track/features/actions/data/action_repository.dart';
import 'package:blue_track/features/actions/domain/action_item.dart';

/// Builds an [ActionItem] with sensible defaults so tests state only what
/// matters for the assertion.
ActionItem buildAction({
  String id = 'a01',
  String title = 'Bersih Pantai Kuta',
  ActionType type = ActionType.beachCleanup,
  DateTime? startsAt,
  DateTime? endsAt,
  String locationName = 'Pantai Kuta, Badung',
  double latitude = -8.7185,
  double longitude = 115.1686,
  int quota = 40,
  int registered = 28,
  String organizerName = 'Komunitas Laut Bersih',
  bool organizerVerified = true,
  String? organizerId = 'o01',
  String imageAsset = '',
  String description = 'Deskripsi kegiatan konservasi.',
  String meetingPoint = 'Pos Pantai Kuta',
  List<String> equipment = const ['Sarung tangan', 'Kantong sampah'],
}) {
  final start = startsAt ?? DateTime(2026, 11, 8, 7);
  return ActionItem(
    id: id,
    title: title,
    type: type,
    startsAt: start,
    endsAt: endsAt ?? start.add(const Duration(hours: 3)),
    locationName: locationName,
    latitude: latitude,
    longitude: longitude,
    quota: quota,
    registered: registered,
    organizerName: organizerName,
    organizerVerified: organizerVerified,
    organizerId: organizerId,
    imageAsset: imageAsset,
    description: description,
    meetingPoint: meetingPoint,
    equipment: equipment,
  );
}

class FakeActionRepository implements ActionRepository {
  FakeActionRepository(this.items);

  final List<ActionItem> items;
  int callCount = 0;
  int detailCallCount = 0;
  final List<String> registerCalls = [];
  bool shouldFailDetail = false;
  bool shouldFailRegistration = false;

  @override
  Future<List<ActionItem>> getActions() async {
    callCount++;
    return items;
  }

  @override
  Future<ActionItem?> getActionById(String id) async {
    detailCallCount++;
    if (shouldFailDetail) throw StateError('simulated detail failure');
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> registerAction(String id) async {
    if (shouldFailRegistration) {
      throw StateError('simulated registration failure');
    }
    registerCalls.add(id);
  }
}

/// Fails the first detail call, succeeds afterwards so the retry path is
/// testable.
class FlakyActionRepository implements ActionRepository {
  FlakyActionRepository(this.items);

  final List<ActionItem> items;
  int failuresRemaining = 1;

  @override
  Future<List<ActionItem>> getActions() async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('simulated failure');
    }
    return items;
  }

  @override
  Future<ActionItem?> getActionById(String id) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('simulated detail failure');
    }
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> registerAction(String id) async {}
}

/// Keeps the loading state pending until the test completes [completer].
class ControlledActionRepository implements ActionRepository {
  final completer = Completer<List<ActionItem>>();
  final detailCompleter = Completer<ActionItem?>();

  @override
  Future<List<ActionItem>> getActions() => completer.future;

  @override
  Future<ActionItem?> getActionById(String id) => detailCompleter.future;

  @override
  Future<void> registerAction(String id) async {}
}

/// In-memory participation store so widget tests never touch
/// `shared_preferences` platform channels.
class InMemoryActionParticipationStore implements ActionParticipationStore {
  InMemoryActionParticipationStore({Map<String, ActionParticipation>? initial})
    : _states = {...?initial};

  final Map<String, ActionParticipation> _states;
  int loadCount = 0;
  bool failLoads = false;
  bool failWrites = false;

  @override
  Future<ActionParticipation> load(String actionId) async {
    loadCount++;
    if (failLoads) throw StateError('simulated store load failure');
    return _states[actionId] ?? const ActionParticipation();
  }

  @override
  Future<void> setRegistered(String actionId, bool registered) async {
    if (failWrites) throw StateError('simulated store write failure');
    final current = _states[actionId] ?? const ActionParticipation();
    _states[actionId] = current.copyWith(registered: registered);
  }

  @override
  Future<void> setReminder(String actionId, bool enabled) async {
    if (failWrites) throw StateError('simulated store write failure');
    final current = _states[actionId] ?? const ActionParticipation();
    _states[actionId] = current.copyWith(reminder: enabled);
  }

  bool isRegistered(String actionId) =>
      _states[actionId]?.registered ?? false;

  bool isReminderOn(String actionId) => _states[actionId]?.reminder ?? false;
}
