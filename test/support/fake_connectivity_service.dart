import 'dart:async';

import 'package:blue_track/core/state/connectivity_service.dart';

/// Controllable [ConnectivityService] for controller and banner tests.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true, this.throwsOnCheck = false});

  /// Answer for [isOnline] and the value emitted by [emit].
  bool online;

  /// When true, [isOnline] throws to mimic a missing platform plugin.
  bool throwsOnCheck;

  int checkCalls = 0;

  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async {
    checkCalls++;
    if (throwsOnCheck) throw StateError('connectivity unavailable');
    return online;
  }

  @override
  Stream<bool> get onOnlineChanged => _changes.stream;

  /// Pushes a network change, like the platform stream would.
  void emit(bool online) {
    this.online = online;
    _changes.add(online);
  }

  Future<void> close() => _changes.close();
}
