import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../project/domain/report.dart';
import '../../../project/presentation/p04_format.dart';
import '../../../project/presentation/p04_report_visuals.dart';

/// Report card in My Reports.
///
/// The category, date, status and severity come from the P04 helpers so the
/// list never drifts from the report visuals used on project pages. The photo
/// leads the card; without one the category icon fills the same slot, keeping
/// every row aligned. The card is a full-width tap target for the detail sheet.
class MyReportCard extends StatelessWidget {
  const MyReportCard({super.key, required this.report, required this.onTap});

  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final categoryColor = context.p04CategoryColor(report.category);

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
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: categoryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
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
                                  lang,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
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
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusPill(
                          icon: context.p04StatusIcon(report.status),
                          label: context.p04StatusLabel(report.status),
                          color: context.p04StatusColor(report.status),
                        ),
                        _SeverityLabel(
                          color: context.p04SeverityColor(report.severity),
                          label: context.p04SeverityLabel(report.severity),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.inactiveTab,
                  ),
                ],
              ),
            ],
          ),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        report.photoPaths.first,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityLabel extends StatelessWidget {
  const _SeverityLabel({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.speed_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          context.tr('my_reports.severity_chip', {'level': label}),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
