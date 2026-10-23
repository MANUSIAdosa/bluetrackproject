import 'package:flutter/material.dart';

import '../../shell/detail_placeholder.dart';

/// P07 — Lapor Temuan placeholder (owner G2, route under proposal).
///
/// No report form here — Part 4+ brings the real flow; this only proves the
/// route opens with a safe back button.
class ReportSubmitPage extends StatelessWidget {
  const ReportSubmitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPlaceholder(
      titleKey: 'detail.report',
      pageCode: 'P07',
    );
  }
}
