import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/donation_timeline.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/skeleton.dart';
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
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Skeleton(height: 132, radius: 16),
              SizedBox(height: 16),
              Skeleton(height: 300, radius: 16),
              SizedBox(height: 16),
              Skeleton(height: 220, radius: 16),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TraceHeader(trace: trace, lang: lang),
          const SizedBox(height: 20),
          Text(
            context.tr('p08_journey'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: DonationTimeline(steps: steps),
          ),
          const SizedBox(height: 16),
          if (trace.projectId.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('p08-view-reports'),
                onPressed: () => context.push(
                  '${Routes.projectDetailUrl(trace.projectId)}?tab=reports',
                ),
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text(context.tr('p08_view_reports')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ocean,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          EReceiptSection(trace: trace),
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

class _TraceHeader extends StatelessWidget {
  const _TraceHeader({required this.trace, required this.lang});

  final DonationTrace trace;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('p08-trace-header'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trace.projectTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trace.organization,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  Formatters.currency(trace.amount, lang),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ocean,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  Formatters.date(trace.donatedAt, lang),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${context.tr('p08_donation_id')}: ${trace.id}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
