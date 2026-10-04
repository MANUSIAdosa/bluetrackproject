import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';

/// Verification badge shown next to organizations and projects.
///
/// Tapping opens a bottom sheet explaining what verification means; pass
/// [onTap] to override that behavior (e.g. to open the organization's own
/// verification sheet with its checklist data).
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.compact = false, this.onTap});

  /// When true, renders icon-only (tight rows such as project cards).
  final bool compact;

  /// Overrides the default "open the explanation sheet" behavior.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = _buildBadge(context);
    if (onTap == null) return badge;

    return Semantics(
      button: true,
      label: context.tr('org.verified.explanation'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: badge,
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context) {
    final label = context.tr('org.verified');
    final badge = compact
        ? const Icon(Icons.verified, size: 16, color: AppColors.teal)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, size: 14, color: AppColors.teal),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
          );

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final override = onTap;
          if (override != null) {
            override();
            return;
          }
          showStaticVerificationSheet(context);
        },
        child: badge,
      ),
    );
  }
}

/// Explains the verification badge: 24dp top corners, centered drag handle,
/// dismissible by dragging down or tapping the barrier.
///
/// Private to this widget so it cannot collide with the organization-specific
/// `showVerificationSheet(context, orgId:)` in `verification_sheet.dart`.
void showStaticVerificationSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const _VerificationSheet(),
  );
}

class _VerificationSheet extends StatelessWidget {
  const _VerificationSheet();

  static const _checklistKeys = [
    'org.checklist.legal',
    'org.checklist.audit',
    'org.checklist.field',
    'org.checklist.finance',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('verify.sheet.title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('verify.sheet.body'),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('org.checklist.title'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final key in _checklistKeys)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr(key),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
