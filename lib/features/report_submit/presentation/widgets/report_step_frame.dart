import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/step_indicator.dart';
import 'report_draft_banner.dart';

/// Shared frame for every step of the "Lapor Temuan" wizard.
///
/// Keeps the four-step indicator, the optional draft banner and the page
/// padding in one place, so steps only describe their own content.
class ReportStepFrame extends StatelessWidget {
  const ReportStepFrame({
    super.key,
    required this.step,
    required this.child,
    this.showDraftBanner = false,
  });

  /// 1-based active step, matching [ReportWizardDraft.currentStep].
  final int step;
  final bool showDraftBanner;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StepIndicator(
            labels: [
              context.tr('report_step_photos'),
              context.tr('report_step_location'),
              context.tr('report_step_type'),
              context.tr('report_step_review'),
            ],
            current: step - 1,
          ),
          if (showDraftBanner) ...[
            const SizedBox(height: 16),
            const ReportDraftBanner(),
          ],
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
