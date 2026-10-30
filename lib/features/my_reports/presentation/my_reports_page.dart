import 'package:flutter/material.dart';

import '../../shell/detail_placeholder.dart';

/// P10 — Laporan Saya placeholder (owner G3, route under proposal).
class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPlaceholder(
      titleKey: 'detail.myReports',
      pageCode: 'P10',
    );
  }
}
