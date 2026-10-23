import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../data/donation_flow_store.dart';
import '../data/donation_repositories.dart';
import '../domain/donation.dart';
import 'widgets/donation_failure_card.dart';
import 'widgets/donation_primary_button.dart';
import 'widgets/donation_status_header.dart';
import 'widgets/donation_status_skeleton.dart';
import 'widgets/donation_summary_card.dart';
import 'widgets/operational_support_card.dart';

/// P06 — payment result (success / failed / pending).
///
/// Registered by the router as `/donate/status/:donationId`.
class DonateStatusPage extends StatefulWidget {
  const DonateStatusPage({
    super.key,
    required this.donationId,
    this.donations,
    this.flowStore,
  });

  final String donationId;
  final DonationRepository? donations;
  final DonationFlowStore? flowStore;

  @override
  State<DonateStatusPage> createState() => _DonateStatusPageState();
}

class _DonateStatusPageState extends State<DonateStatusPage> {
  late final DonationRepository _donations =
      widget.donations ?? DonationRepositories.donations;
  late final DonationFlowStore _flowStore =
      widget.flowStore ?? DonationFlowStore.instance;

  Donation? _donation;
  bool _loading = true;
  bool _notFound = false;
  bool _loadError = false;
  bool _checking = false;
  bool _stillPending = false;
  bool _operationalDismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final donation = await _donations.getDonationStatus(widget.donationId);
      if (!mounted) return;
      setState(() {
        _donation = donation;
        _loading = false;
        _notFound = donation == null;
        _loadError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _loading = true;
      _notFound = false;
      _loadError = false;
    });
    _load();
  }

  Future<void> _checkStatus() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _stillPending = false;
    });
    try {
      final donation = await _donations.getDonationStatus(widget.donationId);
      if (!mounted) return;
      setState(() {
        _checking = false;
        if (donation == null) {
          _donation = null;
          _notFound = true;
        } else {
          _donation = donation;
          _stillPending = donation.status == DonationStatus.pending;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.tr('p06_result_load_error'))),
        );
    }
  }

  void _tryAgain(Donation donation) {
    _flowStore.save(donation.toDraft());
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/donate/${donation.projectId}?step=3');
  }

  void _backToExplore() => context.go('/explore');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('p06_result_title')),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              _backToExplore();
            }
          },
        ),
      ),
      body: Column(
        children: [
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: const OfflineBanner(),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Semantics(
        label: context.tr('p06_result_loading'),
        container: true,
        child: const ExcludeSemantics(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: DonationStatusSkeleton(),
          ),
        ),
      );
    }
    if (_notFound || _loadError) return _buildError(context);
    final donation = _donation;
    if (donation == null) return _buildError(context);
    return _buildContent(context, donation);
  }

  Widget _buildError(BuildContext context) {
    final message = _notFound
        ? context.tr('p06_result_not_found')
        : context.tr('p06_result_load_error');
    return Column(
      children: [
        Expanded(child: ErrorState(message: message, onRetry: _retryLoad)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _backToExplore,
              child: Text(context.tr('p06_result_back_explore')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, Donation donation) {
    final lang = Localizations.localeOf(context).languageCode;
    final isSuccess = donation.status == DonationStatus.success;
    final isFailed = donation.status == DonationStatus.failed;
    final isPending = donation.status == DonationStatus.pending;
    // TODO(mock): read the failure reason from the repository once the real
    // payment API can return one. The ending-in-1 rule lives in
    // MockPaymentConfig and is only used to explain the current mock failure.
    final isMockEndingOneFailure = isFailed && donation.amount % 10 == 1;

    final String primaryKey;
    final VoidCallback? primaryAction;
    if (isSuccess) {
      primaryKey = 'p06_result_view_trace';
      // P08 lands on the Donation Trace placeholder until the real
      // e-receipt screen (P08) is built.
      primaryAction = () =>
          context.push(Routes.donationTraceUrl(donation.id));
    } else if (isFailed) {
      primaryKey = 'p06_result_try_again';
      primaryAction = () => _tryAgain(donation);
    } else {
      primaryKey = 'p06_result_check_status';
      primaryAction = _checking ? null : _checkStatus;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          DonationStatusHeader(
            status: donation.status,
            title: context.tr(_titleKey(donation.status)),
            body: context.tr(_bodyKey(donation.status)),
            semanticsLabel: context.tr(_semanticsKey(donation.status)),
          ),
          const SizedBox(height: 24),
          if (isFailed) ...[
            DonationFailureCard(
              title: context.tr('p06_failure_title'),
              cause: context.tr(
                isMockEndingOneFailure
                    ? 'p06_failure_mock_ending_one'
                    : 'p06_failure_mock_generic',
              ),
              solutionLabel: context.tr('p06_failure_solution_label'),
              solution: context.tr(
                isMockEndingOneFailure
                    ? 'p06_failure_mock_ending_one_solution'
                    : 'p06_failure_mock_generic_solution',
                isMockEndingOneFailure
                    ? {'amount': Formatters.currency(100000, lang)}
                    : const {},
              ),
            ),
            const SizedBox(height: 24),
          ],
          DonationSummaryCard(
            title: context.tr('p06_result_summary_title'),
            items: [
              DonationSummaryItem(
                label: context.tr('p06_result_amount'),
                value: Formatters.currency(donation.amount, lang),
                emphasize: true,
              ),
              DonationSummaryItem(
                label: context.tr('p06_result_project'),
                value: donation.projectName,
              ),
              DonationSummaryItem(
                label: context.tr('p06_result_receipt'),
                value: donation.receiptNumber,
              ),
            ],
          ),
          if (isPending && _stillPending) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    context.tr('p06_result_still_pending'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          DonationPrimaryButton(
            label: context.tr(primaryKey),
            loading: _checking,
            onPressed: primaryAction,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _backToExplore,
              child: Text(context.tr('p06_result_back_explore')),
            ),
          ),
          if (isSuccess && !_operationalDismissed) ...[
            const SizedBox(height: 16),
            OperationalSupportCard(
              onDismiss: () => setState(() => _operationalDismissed = true),
              // TODO(router): `/donate/platform` is expected from G1; the page
              // itself is out of scope.
              onSupport: () => context.push('/donate/platform'),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _titleKey(DonationStatus status) {
    return switch (status) {
      DonationStatus.success => 'p06_result_success_title',
      DonationStatus.failed => 'p06_result_failed_title',
      DonationStatus.pending => 'p06_result_pending_title',
    };
  }

  String _bodyKey(DonationStatus status) {
    return switch (status) {
      DonationStatus.success => 'p06_result_success_body',
      DonationStatus.failed => 'p06_result_failed_body',
      DonationStatus.pending => 'p06_result_pending_body',
    };
  }

  String _semanticsKey(DonationStatus status) {
    return switch (status) {
      DonationStatus.success => 'p06_result_success_semantics',
      DonationStatus.failed => 'p06_result_failed_semantics',
      DonationStatus.pending => 'p06_result_pending_semantics',
    };
  }
}
