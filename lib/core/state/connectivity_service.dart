import 'package:connectivity_plus/connectivity_plus.dart';

/// Network availability contract used by `OfflineController`.
///
/// Kept behind an interface so widget tests can drive online/offline
/// transitions without the platform plugin, and so a future API health check
/// could replace the link-level check without touching the controller.
abstract interface class ConnectivityService {
  /// Whether the device currently has a network link.
  Future<bool> isOnline();

  /// Emits `true` when a link appears and `false` when the last one goes away.
  Stream<bool> get onOnlineChanged;
}

/// `connectivity_plus`-backed [ConnectivityService].
///
/// This reports whether a network interface is available, not whether the
/// internet is actually reachable. That is enough for BlueTrack's mock data:
/// when no interface exists, the app switches to its saved/offline state.
class PlatformConnectivityService implements ConnectivityService {
  PlatformConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async =>
      _isOnline(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onOnlineChanged =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
