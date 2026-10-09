import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/widgets/login_prompt_card.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../shell/tab_placeholder.dart';

/// P09 My Impact — tab shell.
///
/// P00 rule: shows a login prompt when signed out instead of blocking without
/// explanation. The full impact dashboard is not assigned to Weeks 01–03.
class ImpactPage extends StatelessWidget {
  const ImpactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('nav.impact')),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: ListenableBuilder(
        listenable: AuthController.instance,
        builder: (context, _) {
          if (!AuthController.instance.signedIn) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: LoginPromptCard(returnLocation: '/impact'),
            );
          }
          return const TabPlaceholder(location: '/impact');
        },
      ),
    );
  }
}
