import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../shell/tab_placeholder.dart';

/// P17 Profile — tab shell.
///
/// Subproject 01 only requires the tab to exist in the App Shell (P00).
/// Profile content (badges, settings, shortcuts to P11/P12/P13/P16) is not
/// assigned to Weeks 01–03; the placeholder explains the tab from the shell
/// tab configuration instead.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.profile'))),
      body: ListenableBuilder(
        listenable: AuthController.instance,
        builder: (context, _) {
          // Read inside the builder: the shell keeps this tab alive, so a value
          // captured in the outer build would stay `false` after sign-in and
          // the sign-out row would never appear.
          final signedIn = AuthController.instance.signedIn;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.tune),
                    title: Text(context.tr('p01.interests.manage')),
                    subtitle: Text(context.tr('p01.interests.later')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.interests),
                  ),
                ),
              ),
              // TODO(lapor): move this entry to the final "Laporan Saya"
              // surface once that page is designed. Kept on Profile so the
              // Lapor Temuan wizard is reachable in Release 1.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.coral,
                    ),
                    title: Text(context.tr('report_title')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.report),
                  ),
                ),
              ),
              if (signedIn)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(context.tr('profile.title')),
                      trailing: TextButton(
                        onPressed: () => AuthController.instance.signOut(),
                        child: Text(context.tr('profile.signOut')),
                      ),
                    ),
                  ),
                ),
              const Expanded(child: TabPlaceholder(location: '/profile')),
            ],
          );
        },
      ),
    );
  }
}
