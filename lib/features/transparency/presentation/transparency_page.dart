import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../shell/tab_placeholder.dart';

/// P07 Transparency — tab shell.
///
/// Subproject 01 only requires the tab to exist in the App Shell (P00).
/// The full P07 screen (Penyaluran / Kantong A / Kantong B tabs) is not
/// assigned to Weeks 01–03, so this stays a public placeholder: no login
/// required, and the tab's purpose comes from the shell tab configuration.
class TransparencyPage extends StatelessWidget {
  const TransparencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.transparency'))),
      body: const TabPlaceholder(location: '/transparency'),
    );
  }
}