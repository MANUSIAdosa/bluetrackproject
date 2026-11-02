import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/donation_timeline.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/progress_bar.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../donation/domain/donation.dart';
import '../data/donation_trace_repository.dart';
import '../domain/donation_trace.dart';
import 'widgets/e_receipt_card.dart';
import 'widgets/proof_preview_sheet.dart';

/// P08 — public donation trace.
///
/// The page needs no login: anyone with the donation id can see the four
/// milestones, the proof previews, and the E-Receipt summary. Data comes from
/// the mock repository behind [DonationTraceRepository], so an API can replace
/// it later.
class DonationTracePage extends StatefulWidget {
  const DonationTracePage({
    super.key,
    required this.donationId,
    this.repository,
  });

  final String donationId;

  /// Test/demo override for the trace data source.
  final DonationTraceRepository? repository;

  @override
  State<DonationTracePage> createState() => _DonationTracePageState();
}

class _DonationTracePageState extends State<DonationTracePage> {
  late final DonationTraceRepository _repository =
      widget.repository ?? MockDonationTraceRepository();

  DonationTrace? _trace;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final trace = await _repository.getById(widget.donationId);
      if (!mounted) return;
      setState(() {
        _trace = trace;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = false;
    });
    _load();
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      Navigator.of(context).maybePop();
      return;
    }
    context.go(Routes.explore);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context),
        ),
        title: Text(context.tr('p08_title')),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Semantics(
        label: context.tr('p08_loading'),
        child: const SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              Skeleton(height: 196, radius: 20),
              SizedBox(height: 24),
              Skeleton(height: 30, radius: 8),
              SizedBox(height: 12),
              Skeleton(height: 300, radius: 16),
              SizedBox(height: 24),
              Skeleton(height: 300, radius: 16),
              SizedBox(height: 32),
              Skeleton(height: 60, radius: 16),
            ],
          ),
        ),
      );
    }

    if (_error) {
      return ErrorState(message: context.tr('p08_load_error'), onRetry: _retry);
    }

    final trace = _trace;
    if (trace == null) {
      return EmptyState(
        icon: Icons.search_off,
        message: context.tr('p08_not_found'),
      );
    }

    return _TraceContent(trace: trace);
  }
}

class _TraceContent extends StatelessWidget {
  const _TraceContent({required this.trace});

  final DonationTrace trace;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final steps = [
      for (final type in DonationTraceStepType.values)
        _buildStep(context, type, lang),
    ];
    final completed = steps.where((step) => step.isComplete).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TraceHeader(trace: trace, lang: lang),
          const SizedBox(height: 24),
          _TraceSectionHeader(
            title: context.tr('p08_journey'),
            completed: completed,
            total: steps.length,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimens.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: DonationTimeline(steps: steps),
          ),
          const SizedBox(height: 24),
          EReceiptSection(trace: trace),
          if (trace.projectId.isNotEmpty) ...[
            const SizedBox(height: 32),
            _ReportLink(projectId: trace.projectId),
          ],
        ],
      ),
    );
  }

  DonationTimelineStep _buildStep(
    BuildContext context,
    DonationTraceStepType type,
    String lang,
  ) {
    final step = trace.stepFor(type);
    final label = _stepLabel(context, type);

    VoidCallback? onTap;
    final canPreviewProof =
        step != null &&
        step.hasPhoto &&
        (type == DonationTraceStepType.proof ||
            type == DonationTraceStepType.fieldUpdate);
    if (canPreviewProof) {
      final proofStep = step;
      onTap = () => showProofPreviewSheet(
        context,
        stepLabel: label,
        photoAsset: proofStep.photoAsset!,
        description: proofStep.description,
        date: proofStep.at,
      );
    }

    return DonationTimelineStep(
      label: label,
      isComplete: step != null,
      timeLabel: step == null ? null : Formatters.date(step.at, lang),
      onTap: onTap,
    );
  }

  String _stepLabel(BuildContext context, DonationTraceStepType type) {
    return switch (type) {
      DonationTraceStepType.received => context.tr('p08_step_received'),
      DonationTraceStepType.forwarded => context.tr('p08_step_forwarded'),
      DonationTraceStepType.proof => context.tr('p08_step_proof'),
      DonationTraceStepType.fieldUpdate => context.tr('p08_step_field_update'),
    };
  }
}

/// Quiet footer entry point to the project reports tab.
///
/// Viewing reports is a rare follow-up after checking the trace, so this is a
/// secondary navigation row rather than a filled CTA: it sits last on the
/// page, keeps a full-width tap target, and signals "opens another page" with
/// its trailing chevron without competing with the donation summary.
class _ReportLink extends StatelessWidget {
  const _ReportLink({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AppDimens.cardRadius);

    return Material(
      color: AppColors.surface,
      borderRadius: borderRadius,
      child: InkWell(
        key: const ValueKey('p08-view-reports'),
        onTap: () => context.push(
          '${Routes.projectDetailUrl(projectId)}?tab=reports',
        ),
        borderRadius: borderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.ocean.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: AppColors.ocean,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('p08_view_reports'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
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
        ),
      ),
    );
  }
}

class _TraceSectionHeader extends StatelessWidget {
  const _TraceSectionHeader({
    required this.title,
    required this.completed,
    required this.total,
  });

  final String title;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.ocean.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$completed/$total',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ocean,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ProgressBar(value: total == 0 ? 0 : completed / total, height: 4),
      ],
    );
  }
}

class _TraceHeader extends StatelessWidget {
  const _TraceHeader({required this.trace, required this.lang});

  final DonationTrace trace;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('p08-trace-header'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.oceanDeep, AppColors.ocean],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ocean.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trace.projectTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trace.organization,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            Formatters.currency(trace.amount, lang),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _TraceStatusChip(status: trace.status),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${context.tr('p08_donation_id')}: ${trace.id}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.66),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.date(trace.donatedAt, lang),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TraceStatusChip extends StatelessWidget {
  const _TraceStatusChip({required this.status});

  final DonationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      DonationStatus.success => (
        context.tr('p08_receipt_status_success'),
        Icons.check_circle_outline,
      ),
      DonationStatus.pending => (
        context.tr('p08_receipt_status_pending'),
        Icons.schedule,
      ),
      DonationStatus.failed => (
        context.tr('p08_receipt_status_failed'),
        Icons.error_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
