import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/notification/data/notification_repository.dart';
import '../../features/repositories.dart';
import '../config/app_config.dart';
import 'connectivity_service.dart';

/// Application-wide controllers (no external state management package).

/// Thin wrapper over flutter_secure_storage so tests and future API auth can
/// swap implementations without touching controllers.
class SecureStorageService {
  SecureStorageService._();

  static final SecureStorageService instance = SecureStorageService._();

  static const _storage = FlutterSecureStorage();

  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Persists the auth token using flutter_secure_storage.
class AuthRepository {
  AuthRepository._();

  static final AuthRepository instance = AuthRepository._();

  static const _tokenKey = 'auth_token';

  Future<String?> readToken() => SecureStorageService.instance.read(_tokenKey);

  Future<String> writeMockToken(String subject) async {
    final token =
        'mock-token-$subject-${DateTime.now().millisecondsSinceEpoch}';
    await SecureStorageService.instance.write(_tokenKey, token);
    return token;
  }

  Future<void> deleteToken() => SecureStorageService.instance.delete(_tokenKey);
}

class AuthController extends ChangeNotifier {
  AuthController._();

  static final AuthController instance = AuthController._();

  bool _signedIn = false;

  bool get signedIn => _signedIn;

  Future<void> init() async {
    final token = await AuthRepository.instance.readToken();
    _signedIn = token != null;
    notifyListeners();
  }

  Future<void> signIn(String emailOrPhone) async {
    await AuthRepository.instance.writeMockToken(emailOrPhone);
    _signedIn = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    await AuthRepository.instance.deleteToken();
    _signedIn = false;
    notifyListeners();
  }

  /// Sets the session flag without touching secure storage. Only for tests:
  /// widget tests cannot reach the platform channel behind the token store.
  @visibleForTesting
  void setSignedIn(bool value) {
    if (_signedIn == value) return;
    _signedIn = value;
    notifyListeners();
  }
}

/// Saved projects backed by the Hive box `saved_projects`.
class SavedProjectsController extends ChangeNotifier {
  SavedProjectsController._();

  static final SavedProjectsController instance = SavedProjectsController._();

  Box<dynamic> get _box => Hive.box<dynamic>(AppConfig.savedProjectsBox);

  final Set<String> _ids = {};

  Set<String> get ids => Set.unmodifiable(_ids);

  Future<void> load() async {
    _ids
      ..clear()
      ..addAll(_box.keys.cast<String>());
  }

  bool isSaved(String id) => _ids.contains(id);

  Future<void> toggle(String id) async {
    if (_ids.contains(id)) {
      _ids.remove(id);
      await _box.delete(id);
    } else {
      _ids.add(id);
      await _box.put(id, true);
    }
    notifyListeners();
  }
}

/// Unread notification count, loaded once from [NotificationRepository].
///
/// Single source of truth: the app-bar bell and the My Impact nav badge both
/// read this, so the two can never disagree. Starts at 0, so no badge shows
/// before [load] resolves.
class NotificationsController extends ChangeNotifier {
  NotificationsController._();

  static final NotificationsController instance = NotificationsController._();

  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  /// True once a count has been read from the repository.
  bool get loaded => _loaded;
  bool _loaded = false;

  Future<void> load({NotificationRepository? repository}) async {
    final count = await (repository ?? Repositories.notifications)
        .getUnreadCount();
    _unreadCount = count < 0 ? 0 : count;
    _loaded = true;
    notifyListeners();
  }
}

/// Offline banner state, driven by the device network interface.
///
/// [start] is called once from `main`. The app starts offline only when no
/// network interface exists; a connected interface is treated as online
/// because BlueTrack's data is mocked locally. Tests pass a fake
/// [ConnectivityService] and call [stop] afterwards.
class OfflineController extends ChangeNotifier {
  OfflineController._();

  static final OfflineController instance = OfflineController._();

  bool _offline = false;
  ConnectivityService? _connectivity;
  StreamSubscription<bool>? _subscription;

  /// Startup must never block the first frame on a slow platform channel.
  static const Duration _startupTimeout = Duration(seconds: 2);

  bool get offline => _offline;

  void setOffline(bool value) {
    if (_offline == value) return;
    _offline = value;
    notifyListeners();
  }

  /// Reads the current link state and subscribes to changes.
  ///
  /// Idempotent: a second call is ignored, so callers never create duplicate
  /// subscriptions. Platform failures leave the last known state untouched and
  /// still allow the app to work with mock data.
  Future<void> start({ConnectivityService? service}) async {
    if (_connectivity != null) return;
    final connectivity = service ?? PlatformConnectivityService();
    _connectivity = connectivity;

    try {
      setOffline(!await connectivity.isOnline().timeout(_startupTimeout));
    } catch (_) {
      // Keep the current state; the banner is best-effort.
    }

    try {
      _subscription = connectivity.onOnlineChanged.listen(
        (online) => setOffline(!online),
        onError: (Object _) {},
      );
    } catch (_) {
      // No connectivity stream on this platform; stay with the last state.
    }
  }

  /// Stops observing connectivity. Used by tests to avoid cross-test leaks.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _connectivity = null;
  }
}

/// Onboarding flags stored in shared_preferences.
class OnboardingState {
  OnboardingState._();

  static Future<void> markDone(List<String> interests) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.onboardingDoneKey, true);
    await prefs.setStringList(AppConfig.interestsKey, interests);
  }

  static Future<List<String>> readInterests() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(AppConfig.interestsKey) ?? const [];
  }
}
