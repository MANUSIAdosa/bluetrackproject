import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';

/// Verification badge shown next to organizations and projects.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.compact = false});

  /// When true, renders icon-only (tight rows such as project cards).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = context.tr('org.verified');
    if (compact) {
      return const Icon(Icons.verified, size: 16, color: AppColors.ocean);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.ocean.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 14, color: AppColors.ocean),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.ocean,
            ),
          ),
        ],
      ),
    );
  }
}
