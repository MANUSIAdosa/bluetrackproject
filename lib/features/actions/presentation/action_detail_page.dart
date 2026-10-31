import 'package:flutter/material.dart';

import '../../shell/detail_placeholder.dart';

/// P15 — Detail Aksi placeholder (route under proposal: `/actions/:id`).
///
/// Opens from the Aksi agenda without colliding with the `/actions` tab
/// branch. No agenda data yet — the received `id` is shown for verification.
class ActionDetailPage extends StatelessWidget {
  const ActionDetailPage({super.key, required this.actionId});

  final String actionId;

  @override
  Widget build(BuildContext context) {
    return DetailPlaceholder(
      titleKey: 'detail.action',
      pageCode: 'P15',
      parameters: [('id', actionId)],
    );
  }
}
