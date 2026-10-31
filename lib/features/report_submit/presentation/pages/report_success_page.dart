import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../project/domain/report.dart';
import '../../../project/presentation/p04_report_visuals.dart';
import '../../data/my_reports_store.dart';

/// Terminal screen shown after a report is sent.
///
/// Back (system gesture or the close button) goes to "Laporan Saya" and never
/// returns to the wizard, so a submitted draft cannot be re-sent by accident.
class ReportSuccessPage extends StatelessWidget {
  const ReportSuccessPage({super.key, required this.reportId, this.store});

  final String reportId;

  /// Test seam; defaults to the session store.
  final MyReportsStore? store;

  @override
  Widget build(BuildContext context) {
    final report = (store ?? MyReportsStore.instance).byId(reportId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/my-reports');
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: report == null
                    ? _ReportNotFound(onBack: () => context.go('/my-reports'))
                    : _SuccessBody(report: report),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const ValueKey('report_success_close'),
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    onPressed: () => context.go('/my-reports'),
                    icon: const Icon(Icons.close),
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

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 52,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('report_success_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('report_success_body'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(
                    label: context.tr('report_review_type'),
                    child: Text(
                      context.p04CategoryLabel(report.category),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: context.tr('report_review_severity'),
                    child: Text(
                      context.p04SeverityLabel(report.severity),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: context.tr('report_success_coordinates'),
                    child: Text(
                      '${report.latitude.toStringAsFixed(6)}, '
                      '${report.longitude.toStringAsFixed(6)}',
                      key: const ValueKey('report_success_coordinates'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: context.tr('report_success_number'),
                    child: Text(
                      report.id,
                      key: const ValueKey('report_success_number'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: context.tr('report_success_status'),
                    child: _StatusChip(status: report.status),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            key: const ValueKey('report_success_view_reports'),
            label: context.tr('report_success_view_reports'),
            onPressed: () => context.go('/my-reports'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('report_success_new_report'),
            // Replace the success screen so back from the fresh form does not
            // return to the report that was just sent.
            onPressed: () => context.pushReplacement('/report'),
            child: Text(context.tr('report_success_new_report')),
          ),
        ],
      ),
    );
  }
}

class _ReportNotFound extends StatelessWidget {
  const _ReportNotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off,
      message: context.tr('report_success_not_found'),
      actionLabel: context.tr('report_success_view_reports'),
      onAction: onBack,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: child),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final color = context.p04StatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(context.p04StatusIcon(status), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            context.p04StatusLabel(status),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
