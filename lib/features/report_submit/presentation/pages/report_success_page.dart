import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../project/domain/report.dart';
import '../../../project/presentation/p04_report_visuals.dart';
import '../../../my_reports/data/my_reports_store.dart';

/// Terminal screen shown after a report is sent.
///
/// Back (system gesture or the close button) goes to Explore and never returns
/// to the wizard, so a submitted draft cannot be re-sent by accident. The
/// success action opens the registered Laporan Saya page.
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
        context.go(Routes.explore);
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: report == null
                    ? _ReportNotFound(
                        onBack: () => context.push(Routes.myReports),
                      )
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
                    onPressed: () => context.go(Routes.explore),
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

  static const EdgeInsets _padding = EdgeInsets.fromLTRB(24, 40, 24, 24);

  @override
  Widget build(BuildContext context) {
    // Centred like the app's other full-page states: the message, the three
    // facts and the two actions read as one closing block. The scroll view
    // keeps small screens usable, where centring would otherwise clip.
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight.isFinite
            ? constraints.maxHeight - _padding.vertical
            : 0.0;

        return SingleChildScrollView(
          padding: _padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: available),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 16),
                Text(
                  context.tr('report_success_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                // Closure, not a report viewer: reference, location and state
                // only. The full report lives in Laporan Saya.
                Text(
                  report.id,
                  key: const ValueKey('report_success_number'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (report.areaName?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Text(
                    report.areaName!.trim(),
                    key: const ValueKey('report_success_area_name'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Coordinates are always shown: at sea they are the only
                // locator the reporter can hand to someone else.
                Text(
                  '${report.latitude.toStringAsFixed(6)}, '
                  '${report.longitude.toStringAsFixed(6)}',
                  key: const ValueKey('report_success_coordinates'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatusChip(status: report.status),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.tr('report_success_status_note'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  key: const ValueKey('report_success_view_reports'),
                  label: context.tr('report_success_view_reports'),
                  onPressed: () => context.push(Routes.myReports),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const ValueKey('report_success_new_report'),
                  // Replace the success screen so back from the fresh form
                  // does not return to the report that was just sent.
                  onPressed: () => context.pushReplacement(Routes.report),
                  child: Text(context.tr('report_success_new_report')),
                ),
              ],
            ),
          ),
        );
      },
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
