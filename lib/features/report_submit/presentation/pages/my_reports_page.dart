import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/offline_banner.dart';
import '../../../project/domain/report.dart';
import '../../../project/presentation/p04_report_visuals.dart';
import '../../data/my_reports_store.dart';

/// "Laporan Saya" — reports sent from this device during the session.
///
/// Data comes from [MyReportsStore] (in memory) so a just-submitted report is
/// visible immediately. Once the report API exists, this page should read
/// `ReportRepository.getReportsByUser` and gain loading/error states.
///
/// TODO(lapor): read from ReportRepository and add loading/error/retry.
class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key, this.store});

  /// Test seam; defaults to the session store.
  final MyReportsStore? store;

  @override
  Widget build(BuildContext context) {
    final store = this.store ?? MyReportsStore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('report_mine_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final reports = store.reports;
                if (reports.isEmpty) {
                  return EmptyState(
                    icon: Icons.assignment_outlined,
                    message: context.tr('report_mine_empty'),
                    actionLabel: context.tr('report_mine_new'),
                    onAction: () => context.push('/report'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) => _ReportCard(
                    key: ValueKey('report_mine_item_${reports[index].id}'),
                    report: reports[index],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({super.key, required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final color = context.p04StatusColor(report.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context
                        .p04CategoryColor(report.category)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    context.p04CategoryIcon(report.category),
                    size: 22,
                    color: context.p04CategoryColor(report.category),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.p04CategoryLabel(report.category),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.p04SeverityLabel(report.severity),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        context.p04StatusIcon(report.status),
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.p04StatusLabel(report.status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.confirmation_number_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  report.id,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.schedule_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    Formatters.dateTime(report.reportedAt, locale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${report.latitude.toStringAsFixed(6)}, '
                    '${report.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
