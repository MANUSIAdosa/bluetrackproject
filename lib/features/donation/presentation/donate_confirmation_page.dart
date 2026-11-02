import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/login_prompt_card.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../explore/data/project_repository.dart';
import '../../explore/domain/project.dart';
import '../../repositories.dart';
import '../data/donation_flow_store.dart';
import '../data/donation_repositories.dart';
import '../domain/donation.dart';
import '../domain/donation_rules.dart';
import 'widgets/donation_primary_button.dart';
import 'widgets/donation_summary_card.dart';
import 'widgets/payment_method_selector.dart';

/// P06 — donation confirmation (Langkah 3).
///
/// Reached directly from the amount step; there is no purpose screen. The
/// draft is kept in [DonationFlowStore] so signing in or stepping back does not
/// lose the user's input.
class DonateConfirmationPage extends StatefulWidget {
  const DonateConfirmationPage({
    super.key,
    required this.projectId,
    this.flowStore,
    this.donations,
    this.payments,
    this.projects,
    this.signedInOverride,
  });

  final String projectId;
  final DonationFlowStore? flowStore;
  final DonationRepository? donations;
  final PaymentRepository? payments;
  final ProjectRepository? projects;

  /// Test/manual seam: when null, [AuthController] is the source of truth.
  final bool? signedInOverride;

  @override
  State<DonateConfirmationPage> createState() => _DonateConfirmationPageState();
}

class _DonateConfirmationPageState extends State<DonateConfirmationPage> {
  late final DonationFlowStore _flowStore =
      widget.flowStore ?? DonationFlowStore.instance;
  late final DonationRepository _donations =
      widget.donations ?? DonationRepositories.donations;
  late final PaymentRepository _payments =
      widget.payments ?? DonationRepositories.payments;
  late final ProjectRepository _projects =
      widget.projects ?? Repositories.projects;

  DonationDraft? _draft;
  Project? _project;
  PaymentMethod? _method;
  bool _showName = false;
  bool _loading = true;
  bool _projectError = false;
  bool _processing = false;
  bool _amountError = false;
  String? _methodError;
  String? _payErrorKey;

  @override
  void initState() {
    super.initState();
    final draft = _flowStore.draft;
    if (draft == null || draft.projectId != widget.projectId) {
      _loading = false;
      return;
    }
    _draft = draft;
    _method = draft.paymentMethod;
    _showName = draft.showNameInReport;
    _amountError = draft.amount < DonationRules.minAmount;
    _loadProject();
  }

  bool get _isSignedIn =>
      widget.signedInOverride ?? AuthController.instance.signedIn;

  DonationDraft? get _currentDraft {
    final draft = _draft;
    if (draft == null) return null;
    return draft.copyWith(
      paymentMethod: _method,
      showNameInReport: _showName,
    );
  }

  Future<void> _loadProject() async {
    try {
      final project = await _projects.getProjectById(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = project;
        _loading = false;
        _projectError = project == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _projectError = true;
      });
    }
  }

  void _retryProject() {
    setState(() {
      _loading = true;
      _projectError = false;
    });
    _loadProject();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/donate/${widget.projectId}');
  }

  void _openAuth() {
    final redirect = Uri.encodeComponent(
      '/donate/${widget.projectId}?step=3',
    );
    context.push('/auth?redirect=$redirect');
  }

  void _selectMethod(PaymentMethod method) {
    setState(() {
      _method = method;
      _methodError = null;
    });
    _persistDraft();
  }

  void _toggleShowName(bool value) {
    setState(() => _showName = value);
    _persistDraft();
  }

  void _persistDraft() {
    final draft = _currentDraft;
    if (draft != null) _flowStore.save(draft);
  }

  Future<void> _pay() async {
    if (_processing) return;
    final draft = _currentDraft;
    final project = _project;
    if (draft == null || project == null) return;

    final amountInvalid = draft.amount < DonationRules.minAmount;
    final methodMissing = _method == null;
    setState(() {
      _amountError = amountInvalid;
      _methodError =
          methodMissing ? context.tr('p06_confirm_method_required') : null;
      _payErrorKey = null;
    });
    if (amountInvalid || methodMissing) return;

    if (!_isSignedIn) {
      _openAuth();
      return;
    }

    setState(() => _processing = true);
    Donation created;
    try {
      created = await _donations.createDonation(
        draft.copyWith(
          projectName: project.title,
          orgName: project.orgName,
        ),
      );
      await _payments.processPayment(created.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _payErrorKey = 'p06_confirm_pay_error';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _processing = false);
    context.push('/donate/status/${created.id}');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.signedInOverride != null) {
      return _buildScaffold(context, widget.signedInOverride!);
    }
    return ListenableBuilder(
      listenable: AuthController.instance,
      builder: (context, _) =>
          _buildScaffold(context, AuthController.instance.signedIn),
    );
  }

  Widget _buildScaffold(BuildContext context, bool signedIn) {
    final showBottomBar = !_loading && !_projectError && _draft != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('p06_confirm_title')),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: Column(
        children: [
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: const OfflineBanner(),
          ),
          Expanded(child: _buildContent(context)),
        ],
      ),
      bottomNavigationBar:
          showBottomBar ? _buildBottomBar(context, signedIn) : null,
    );
  }

  Widget _buildBottomBar(BuildContext context, bool signedIn) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: signedIn
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_payErrorKey != null) ...[
                      Text(
                        context.tr(_payErrorKey!),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Semantics(
                      liveRegion: _processing,
                      label: _processing
                          ? context.tr('p06_confirm_processing')
                          : null,
                      child: DonationPrimaryButton(
                        label: context.tr('p06_confirm_pay_button'),
                        loading: _processing,
                        onPressed: _processing ? null : _pay,
                      ),
                    ),
                  ],
                )
              : LoginPromptCard(
                  returnLocation: Uri.encodeComponent(
                    '/donate/${widget.projectId}?step=3',
                  ),
                  title: context.tr('p06_confirm_login_title'),
                  body: context.tr('p06_confirm_login_body'),
                ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) return const _ConfirmationSkeleton();
    if (_projectError) {
      return ErrorState(
        message: context.tr('p06_confirm_project_error'),
        onRetry: _retryProject,
      );
    }

    final draft = _draft;
    final project = _project;
    if (draft == null || project == null) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        message: '${context.tr('p06_confirm_empty_title')}\n'
            '${context.tr('p06_confirm_empty_body')}',
        actionLabel: context.tr('p06_confirm_back_to_amount'),
        onAction: () => context.go('/donate/${widget.projectId}'),
      );
    }

    final lang = Localizations.localeOf(context).languageCode;
    final amount = Formatters.currency(draft.amount, lang);
    final target = draft.purpose == DonationPurpose.organization
        ? project.orgName
        : project.title;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BigConfirmationCard(
            amount: amount,
            name: target,
            isProject: draft.purpose == DonationPurpose.project,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              context.tr('p06_confirm_min_hint', {
                'amount': Formatters.currency(DonationRules.minAmount, lang),
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: _amountError ? FontWeight.w600 : FontWeight.w400,
                color:
                    _amountError ? AppColors.danger : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          DonationSummaryCard(
            title: context.tr('p06_confirm_summary_title'),
            items: [
              DonationSummaryItem(
                label: context.tr('p06_confirm_amount'),
                value: amount,
                emphasize: true,
              ),
              DonationSummaryItem(
                label: context.tr('p06_confirm_frequency'),
                value: _frequencyLabel(context, draft.frequency),
              ),
              DonationSummaryItem(
                label: context.tr('p06_confirm_purpose'),
                value: context.tr(
                  draft.purpose == DonationPurpose.organization
                      ? 'p06_confirm_purpose_org'
                      : 'p06_confirm_purpose_project',
                  {'name': target},
                ),
              ),
              DonationSummaryItem(
                label: context.tr('p06_confirm_method'),
                value: _method == null
                    ? context.tr('p06_confirm_method_empty')
                    : _methodLabel(context, _method!),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PaymentMethodSelector(
            selected: _method,
            onChanged: _selectMethod,
            errorText: _methodError,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _showName,
            onChanged: (value) => _toggleShowName(value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.tr('p06_confirm_show_name'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _frequencyLabel(BuildContext context, DonationFrequency frequency) {
    return context.tr(
      frequency == DonationFrequency.monthly
          ? 'p06_confirm_frequency_monthly'
          : 'p06_confirm_frequency_once',
    );
  }

  String _methodLabel(BuildContext context, PaymentMethod method) {
    return switch (method) {
      PaymentMethod.virtualAccount => context.tr('p06_confirm_method_va'),
      PaymentMethod.eWallet => context.tr('p06_confirm_method_ewallet'),
      PaymentMethod.card => context.tr('p06_confirm_method_card'),
    };
  }
}

/// Donation identity card at the top of the confirmation step.
///
/// Shows one thing per line — heart, "your donation", amount, the 100% badge
/// and the project name — instead of the old single sentence with an arrow.
/// Keeping the amount and the name on separate lines makes the card readable
/// at a glance and leaves room for long project titles.
class _BigConfirmationCard extends StatelessWidget {
  const _BigConfirmationCard({
    required this.amount,
    required this.name,
    required this.isProject,
  });

  /// Already formatted with the active locale.
  final String amount;

  /// Project title, or organization name for an organization-purpose draft.
  final String name;

  /// Whether this donation supports a project. Organization-purpose drafts are
  /// not created by the current flow, but their badge must not claim "100% to
  /// the project" if Fund B is ever exposed.
  final bool isProject;

  @override
  Widget build(BuildContext context) {
    final badgeKey = isProject
        ? 'p06_confirm_project_badge'
        : 'p06_confirm_platform_badge';

    return Container(
      key: const Key('p06_confirmation_card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.coral,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('p06_confirm_donation_label'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.oceanDeep,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: AppColors.teal,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    context.tr(badgeKey),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: AppColors.oceanDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationSkeleton extends StatelessWidget {
  const _ConfirmationSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: 148, radius: 16),
          SizedBox(height: 12),
          Skeleton(width: 180, height: 12),
          SizedBox(height: 20),
          Skeleton(height: 190, radius: 16),
          SizedBox(height: 16),
          Skeleton(height: 230, radius: 16),
          SizedBox(height: 12),
          Skeleton(height: 48, radius: 8),
        ],
      ),
    );
  }
}
