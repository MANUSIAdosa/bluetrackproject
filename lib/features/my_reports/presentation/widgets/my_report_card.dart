import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/report_metadata_chip.dart';
import '../../../project/domain/report.dart';
import '../../../project/presentation/p04_format.dart';
import '../../../project/presentation/p04_report_visuals.dart';

/// Report card in My Reports.
///
/// The category, date, status and severity come from the P04 helpers so the
/// list never drifts from the report visuals used on project pages. The photo
/// leads the card; without one the category icon fills the same slot, keeping
/// every row aligned. The card remains a full-width tap target for its detail.
class MyReportCard extends StatelessWidget {
  const MyReportCard({
    super.key,
    required this.report,
    required this.onTap,
    this.onCompletionProofTap,
  });

  final Report report;
  final VoidCallback onTap;
  final VoidCallback? onCompletionProofTap;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final textTheme = Theme.of(context).textTheme;
    final categoryColor = context.p04CategoryColor(report.category);
    final statusColor = context.p04StatusColor(report.status);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        key: ValueKey('my-report-${report.id}'),
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(AppDimens.cardRadius),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LeadingVisual(
                        report: report,
                        categoryColor: categoryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.p04CategoryLabel(report.category),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: categoryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              report.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    P04Format.date(
                                      report.reportedAt.toLocal(),
                                      languageCode,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ReportMetadataChip(
                              icon: context.p04StatusIcon(report.status),
                              label: context.p04StatusLabel(report.status),
                              color: statusColor,
                              iconSize: 14,
                              fontSize: 12,
                            ),
                            ReportMetadataChip(
                              icon: Icons.speed_outlined,
                              label: context.tr('my_reports.severity_chip', {
                                'level': context.p04SeverityLabel(
                                  report.severity,
                                ),
                              }),
                              color: context.p04SeverityColor(report.severity),
                              filled: false,
                              padding: EdgeInsets.zero,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            if (report.status == ReportStatus.completed &&
                                report.hasCompletionProof)
                              _CompletionProofMarker(
                                onTap: onCompletionProofTap ?? onTap,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 20,
                        height: 24,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: AppColors.inactiveTab,
                          ),
                        ),
                      ),
                    ],
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

/// Photo when the report has one, otherwise the category tile.
class _LeadingVisual extends StatelessWidget {
  const _LeadingVisual({required this.report, required this.categoryColor});

  final Report report;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        context.p04CategoryIcon(report.category),
        size: 26,
        color: categoryColor,
      ),
    );

    if (!report.hasPhoto) return placeholder;

    return Semantics(
      image: true,
      label: context.tr('my_reports.card_photo_semantics'),
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            report.photoPaths.first,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          ),
        ),
      ),
    );
  }
}

class _CompletionProofMarker extends StatelessWidget {
  const _CompletionProofMarker({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.tr('my_reports.completion_proof_available');
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          key: const ValueKey('my-report-proof-marker'),
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              heightFactor: 1,
              child: ReportMetadataChip(
                icon: Icons.fact_check_outlined,
                label: label,
                color: AppColors.success,
                fontSize: 12,
                maxLabelLines: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
