import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_localizations.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';

class BlueTrackApp extends StatefulWidget {
  const BlueTrackApp({super.key, required this.onboardingDone});

  final bool onboardingDone;

  @override
  State<BlueTrackApp> createState() => _BlueTrackAppState();
}

class _BlueTrackAppState extends State<BlueTrackApp> {
  late final GoRouter _router = createRouter(
    onboardingDone: widget.onboardingDone,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BlueTrack',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
