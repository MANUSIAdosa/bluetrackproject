import 'package:flutter/material.dart';

import '../../shell/detail_placeholder.dart';

/// P16 — Belajar placeholder (owner G4).
///
/// Public learning content needs no login; the real screen replaces this.
class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPlaceholder(
      titleKey: 'detail.learn',
      pageCode: 'P16',
    );
  }
}
