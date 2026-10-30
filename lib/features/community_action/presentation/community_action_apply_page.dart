import 'package:flutter/material.dart';

import '../../shell/detail_placeholder.dart';

/// P11 — Ajukan Aksi Komunitas placeholder (owner G2, route under proposal).
///
/// The grant-proposal flow of the old concept does NOT return here; this
/// placeholder only anchors the route until the community-action flow lands.
class CommunityActionApplyPage extends StatelessWidget {
  const CommunityActionApplyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailPlaceholder(
      titleKey: 'detail.communityApply',
      pageCode: 'P11',
    );
  }
}
