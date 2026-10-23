import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../shell/tab_placeholder.dart';

/// Aksi tab shell (revised concept: Lapor → Pantau → Aksi → Dukung).
///
/// Only the tab itself is in scope (P00, Periode 2 part 2): this stays a
/// placeholder under the provisional `/actions` route — the full Aksi screen
/// is a later part. As with the other tab shells, the tab's purpose line comes
/// from the shell tab configuration, never from this page.
class ActionsPage extends StatelessWidget {
  const ActionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.aksi'))),
      body: const TabPlaceholder(location: '/actions'),
    );
  }
}
