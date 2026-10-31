import 'package:flutter/material.dart';

import '../../shell/detail_placeholder.dart';

/// P17 — Pengaturan placeholder.
///
/// Reachable from Profil; account management content comes later.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPlaceholder(
      titleKey: 'detail.settings',
      pageCode: 'P17',
    );
  }
}
