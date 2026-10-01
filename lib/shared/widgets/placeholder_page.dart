import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import 'empty_state.dart';

/// Generic "not in this subproject" page with a back button.
///
/// Used for routes that exist in the spec but are intentionally deferred
/// (e.g. P13 during Subproject 01).
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.titleKey});

  final String titleKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(titleKey))),
      body: EmptyState(
        icon: Icons.schedule,
        message: context.tr('common.comingSoon'),
      ),
    );
  }
}
