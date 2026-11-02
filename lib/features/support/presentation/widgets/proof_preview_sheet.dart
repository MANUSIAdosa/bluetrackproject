import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

/// Opens the proof preview for a timeline milestone that has a photo.
///
/// Mirrors the P04 report sheet: a drag handle, rounded top corners, and a
/// scrollable body. The caller passes already-localized text for the milestone
/// and the raw date, so the sheet stays independent from the trace domain.
Future<void> showProofPreviewSheet(
  BuildContext context, {
  required String stepLabel,
  required String photoAsset,
  required String? description,
  required DateTime date,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.cardRadius),
      ),
    ),
    builder: (sheetContext) {
      final lang = Localizations.localeOf(sheetContext).languageCode;
      return _ProofPreviewSheet(
        stepLabel: stepLabel,
        photoAsset: photoAsset,
        description: description,
        dateLabel: Formatters.date(date, lang),
      );
    },
  );
}

class _ProofPreviewSheet extends StatelessWidget {
  const _ProofPreviewSheet({
    required this.stepLabel,
    required this.photoAsset,
    required this.description,
    required this.dateLabel,
  });

  final String stepLabel;
  final String photoAsset;
  final String? description;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final hasDescription = description?.trim().isNotEmpty ?? false;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('p08-proof-sheet'),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.padding,
          0,
          AppDimens.padding,
          24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('p08_proof_preview_title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stepLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('p08-proof-close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: context.tr('p08_proof_close'),
                  icon: const Icon(Icons.close),
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: AppDimens.padding),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Semantics(
                  image: true,
                  label: context.tr('p08_proof_photo_semantics'),
                  child: Image.asset(
                    photoAsset,
                    key: const ValueKey('p08-proof-photo'),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _PhotoError(
                      message: context.tr('p08_proof_photo_error'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.padding),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr('p08_proof_date'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.padding),
            Text(
              context.tr('p08_proof_description'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasDescription
                  ? description!.trim()
                  : context.tr('p08_proof_no_description'),
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoError extends StatelessWidget {
  const _PhotoError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.border,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppDimens.padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            size: 32,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
