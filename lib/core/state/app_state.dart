import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

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

/// Offline banner state.
///
/// TODO(connectivity): plug a real connectivity source here once approved;
/// no connectivity package is currently allowed in pubspec.
class OfflineController extends ChangeNotifier {
  OfflineController._();

  static final OfflineController instance = OfflineController._();

  bool _offline = false;

  bool get offline => _offline;

  void setOffline(bool value) {
    if (_offline == value) return;
    _offline = value;
    notifyListeners();
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
