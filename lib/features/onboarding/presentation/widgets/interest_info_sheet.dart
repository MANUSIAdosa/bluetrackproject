import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// One interest category shown in the onboarding info sheet.
class InterestInfoEntry {
  const InterestInfoEntry({
    required this.id,
    required this.label,
    required this.description,
    required this.imagePath,
  });

  final String id;
  final String label;
  final String description;
  final String imagePath;
}

/// Explains the five onboarding interests and what each one matches in
/// Explore.
///
/// The copy is a draft awaiting team approval; this sheet only presents it and
/// does not change the interest selection or project mapping.
Future<void> showInterestInfoSheet(
  BuildContext context, {
  required List<InterestInfoEntry> entries,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _InterestInfoSheet(entries: entries),
  );
}

class _InterestInfoSheet extends StatelessWidget {
  const _InterestInfoSheet({required this.entries});

  final List<InterestInfoEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          key: const ValueKey('interestInfo.sheet'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('p01.interests.info.title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('interestInfo.close'),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in entries)
                        _InterestInfoRow(entry: entry),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterestInfoRow extends StatelessWidget {
  const _InterestInfoRow({required this.entry});

  final InterestInfoEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('interestInfo.row.${entry.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              entry.imagePath,
              key: ValueKey('interestInfo.image.${entry.id}'),
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stack) => const SizedBox(
                width: 56,
                height: 56,
                child: ColoredBox(
                  color: AppColors.border,
                  child: Icon(Icons.image_not_supported_outlined, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
