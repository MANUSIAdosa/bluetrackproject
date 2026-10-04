import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/widgets/empty_state.dart';

/// P17 Profile — tab shell.
///
/// Subproject 01 only requires the tab to exist in the App Shell (P00).
/// Profile content (badges, settings, shortcuts to P11/P12/P13/P16) is not
/// assigned to Weeks 01–03.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final signedIn = AuthController.instance.signedIn;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile.title'))),
      body: ListenableBuilder(
        listenable: AuthController.instance,
        builder: (context, _) {
          return Column(
            children: [
              if (signedIn)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(context.tr('profile.title')),
                      trailing: TextButton(
                        onPressed: () =>
                            AuthController.instance.signOut(),
                        child: Text(context.tr('profile.signOut')),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: EmptyState(
                  icon: Icons.settings_outlined,
                  message: context.tr('common.comingSoon'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
