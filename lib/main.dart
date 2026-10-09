import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local storage bootstrap: Hive for saved projects, shared_preferences for
  // onboarding flags/interests, secure storage for the auth token (via AuthRepository).
  await Hive.initFlutter();
  await Hive.openBox<dynamic>(AppConfig.savedProjectsBox);
  await SavedProjectsController.instance.load();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool(AppConfig.onboardingDoneKey) ?? false;

  await AuthController.instance.init();
  await NotificationsController.instance.load();

  runApp(BlueTrackApp(onboardingDone: onboardingDone));
}
