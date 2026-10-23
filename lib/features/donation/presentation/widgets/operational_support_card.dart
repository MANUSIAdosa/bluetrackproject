import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Optional Fund B ask shown only after a successful donation.
class OperationalSupportCard extends StatelessWidget {
  const OperationalSupportCard({
    super.key,
    required this.onDismiss,
    required this.onSupport,
  });

  final VoidCallback onDismiss;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.teal.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('p06_result_operational_title'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('p06_operational_card_dismiss'),
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                context.tr('p06_result_operational_body'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onSupport,
              child: Text(context.tr('p06_result_operational_cta')),
            ),
          ],
        ),
      ),
    );
  }
}
