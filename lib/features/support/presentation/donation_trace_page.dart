import 'package:flutter/material.dart';

import '../../shell/detail_placeholder.dart';

/// P08 — Jejak Dukungan & E-Receipt placeholder (owner G3).
///
/// Route under proposal: `/support/trace/:donationId` replaces the old,
/// never-routed `/transparency/trace/:donationId` push. Public trace data
/// needs no login; the real screen replaces this placeholder.
class DonationTracePage extends StatelessWidget {
  const DonationTracePage({super.key, required this.donationId});

  final String donationId;

  @override
  Widget build(BuildContext context) {
    return DetailPlaceholder(
      titleKey: 'detail.donationTrace',
      pageCode: 'P08',
      parameters: [('donationId', donationId)],
    );
  }
}
