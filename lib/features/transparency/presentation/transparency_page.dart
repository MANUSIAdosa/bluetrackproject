import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/empty_state.dart';

/// P07 Transparency — tab shell.
///
/// Subproject 01 only requires the tab to exist in the App Shell (P00).
/// The full P07 screen (Penyaluran / Kantong A / Kantong B tabs) is not
/// assigned to Weeks 01–03, so this stays a public placeholder.
class TransparencyPage extends StatelessWidget {
  const TransparencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('transparency.title'))),
      body: EmptyState(
        icon: Icons.account_balance_outlined,
        message: context.tr('common.comingSoon'),
      ),
    );
  }
}
