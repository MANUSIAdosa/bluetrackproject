import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Static legal documents: Privacy Policy and Terms & Conditions.
///
/// Content is mock/draft text owned by the product owner (see the
/// `legal.*` localization keys). Sections render as cards to match the
/// existing card style (16dp radius, no elevation, from the app theme).
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.documentKey});

  /// Which document to show: `'privacy'` or `'terms'`.
  final String documentKey;

  static const int _sectionCount = 5;

  @override
  Widget build(BuildContext context) {
    final title = context.tr('legal.$documentKey.title');
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('legal.$documentKey.intro'),
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 1; i <= _sectionCount; i++) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('legal.$documentKey.s$i.title'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('legal.$documentKey.s$i.body'),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < _sectionCount) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
