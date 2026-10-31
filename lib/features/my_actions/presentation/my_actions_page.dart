import 'package:flutter/material.dart';

import '../../shell/detail_placeholder.dart';

/// P12 — Aksi Saya placeholder (owner G3, route under proposal).
class MyActionsPage extends StatelessWidget {
  const MyActionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPlaceholder(
      titleKey: 'detail.myActions',
      pageCode: 'P12',
    );
  }
}
