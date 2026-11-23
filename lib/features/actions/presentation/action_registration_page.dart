import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/step_indicator.dart';
import '../data/action_participation_store.dart';
import '../data/action_registration_draft.dart';
import '../data/action_repository.dart';
import '../domain/action_item.dart';
import 'widgets/action_equipment_list.dart';
import 'widgets/action_status_chip.dart';

/// Why a confirmation could not be sent.
enum _BlockReason { full, closed }

/// Full-page registration wizard for one action (P04 family).
///
/// Four steps, mirroring the "Lapor Temuan" wizard: equipment check →
/// participant → review → done. Nothing is written until step 3 confirms, and
/// success is only shown after both the repository write and the local
/// participation write succeed.
class ActionRegistrationPage extends StatefulWidget {
  const ActionRegistrationPage({
    super.key,
    required this.actionId,
    this.repository,
    this.participationStore,
    this.draftStore,
    this.resume = false,
    this.now,
  });

  final String actionId;

  /// Test/demo overrides; the router constructs the page with only [actionId].
  final ActionRepository? repository;
  final ActionParticipationStore? participationStore;
  final ActionRegistrationDraftStore? draftStore;

  /// True when the user is coming back from login and must land on the step
  /// they left from, with the equipment statement restored.
  final bool resume;

  /// Test/clock seam; defaults to [DateTime.now].
  final DateTime Function()? now;

  @override
  State<ActionRegistrationPage> createState() => _ActionRegistrationPageState();
}

class _ActionRegistrationPageState extends State<ActionRegistrationPage> {
  static const _lastFormStep = 3;
  static const _successStep = 4;

  late final ActionRepository _repository =
      widget.repository ?? const MockActionRepository();
  late final ActionParticipationStore _participationStore =
      widget.participationStore ?? const PrefsActionParticipationStore();
  late final ActionRegistrationDraftStore _draftStore =
      widget.draftStore ?? InMemoryActionRegistrationDraftStore.instance;

  DateTime get _now => (widget.now ?? DateTime.now)();

  ActionItem? _item;
  int _step = 1;
  bool _equipmentAcked = false;
  bool _loading = true;
  bool _error = false;
  bool _submitting = false;
  bool _alreadyRegistered = false;
  _BlockReason? _blocked;
  bool _submitFailed = false;
  /// Display name from the signed-in session — the same source the My Impact
  /// page greets the user with. Read after the content is on screen so a slow
  /// or unavailable secure-storage channel never blocks the wizard.
  String? _participantName;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _blocked = null;
      _submitFailed = false;
    });

    ActionItem? item;
    try {
      item = await _repository.getActionById(widget.actionId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }

    if (!mounted) return;
    if (item == null) {
      setState(() {
        _loading = false;
        _item = null;
      });
      return;
    }

    var registered = false;
    try {
      final participation = await _participationStore.load(item.id);
      registered = participation.registered;
    } catch (_) {
      registered = false;
    }

    final draft = widget.resume ? _draftStore.load(item.id) : null;
    if (!mounted) return;

    setState(() {
      _item = item;
      _alreadyRegistered = registered;
      // Only the session state the app really holds; participant columns from
      // the per-page specification are not available yet.
      _participantName = null;
      // A registration that already exists reopens on the result step: the
      // wizard must never look like it is offering a second registration.
      _step = registered
          ? _successStep
          : (draft?.step ?? 1).clamp(1, _lastFormStep);
      _equipmentAcked = registered || (draft?.equipmentAcked ?? false);
      _loading = false;
    });

    _loadParticipantName();
  }

  void _loadParticipantName() {
    AuthRepository.instance
        .readDisplayName()
        .then((name) {
          if (!mounted) return;
          setState(() => _participantName = name);
        })
        .catchError((Object _) {
          // Keep the localized fallback; the wizard stays usable.
        });
  }

  /// The name shown on the participant step and in the review.
  String _participantLabel(BuildContext context) =>
      _participantName ?? context.tr('impact.greetingFallback');

  bool get _equipmentRequired => (_item?.equipment.isNotEmpty ?? false);

  bool get _canContinueFromEquipment => !_equipmentRequired || _equipmentAcked;

  void _goToStep(int step) {
    setState(() {
      _step = step;
      _submitFailed = false;
      _blocked = null;
    });
    _saveDraft();
  }

  void _saveDraft() {
    if (_step >= _successStep) return;
    _draftStore.save(
      ActionRegistrationDraft(
        actionId: widget.actionId,
        step: _step,
        equipmentAcked: _equipmentAcked,
      ),
    );
  }

  Future<void> _handleBack() async {
    if (_step > 1 && _step < _successStep) {
      _goToStep(_step - 1);
      return;
    }
    await _leave();
  }

  Future<void> _leave() async {
    _draftStore.clear();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(Routes.actionAgenda);
    }
  }

  /// Step 3 → write the registration.
  Future<void> _confirm() async {
    final item = _item;
    if (item == null || _submitting) return;

    // Login is required for registration. The draft keeps the step and the
    // equipment answer so the user returns to this exact step after signing
    // in (the login page replaces the route via `redirect`).
    if (!AuthController.instance.signedIn) {
      _saveDraft();
      final redirect = Uri.encodeComponent(
        '${Routes.actionRegisterUrl(item.id)}?resume=1',
      );
      await context.push('${Routes.auth}?redirect=$redirect');
      return;
    }

    setState(() {
      _submitting = true;
      _submitFailed = false;
      _blocked = null;
    });

    // Re-read the action first: the quota may have filled up, or the activity
    // may have started, while the user was filling the wizard. Nothing is sent
    // when that happened.
    ActionItem? fresh;
    try {
      fresh = await _repository.getActionById(item.id);
    } catch (_) {
      fresh = null;
    }
    if (!mounted) return;
    if (fresh == null) {
      setState(() {
        _submitting = false;
        _submitFailed = true;
      });
      return;
    }
    if (fresh.isFull) {
      setState(() {
        _item = fresh;
        _submitting = false;
        _blocked = _BlockReason.full;
      });
      return;
    }
    if (!fresh.canRegisterAt(_now)) {
      setState(() {
        _item = fresh;
        _submitting = false;
        _blocked = _BlockReason.closed;
      });
      return;
    }

    try {
      await _repository.registerAction(fresh.id);
      await _participationStore.setRegistered(fresh.id, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitFailed = true;
      });
      return;
    }

    // Only now is the result shown. The refreshed action carries the updated
    // participant count from the data source.
    ActionItem updated = fresh;
    try {
      updated = await _repository.getActionById(fresh.id) ?? fresh;
    } catch (_) {
      updated = fresh;
    }

    _draftStore.clear();
    if (!mounted) return;
    setState(() {
      _item = updated;
      _alreadyRegistered = true;
      _submitting = false;
      _step = _successStep;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 1 || _step == _successStep,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('action.register.title')),
          leading: BackButton(onPressed: _handleBack),
        ),
        body: _buildBody(context),
        bottomNavigationBar: _loading || _error || _item == null
            ? null
            : _buildBottomBar(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        key: ValueKey('action.register.loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (_error) {
      return ErrorState(
        key: const ValueKey('action.register.error'),
        message: context.tr('action.register.loadFailed'),
        onRetry: _load,
      );
    }

    final item = _item;
    if (item == null) {
      return EmptyState(
        key: const ValueKey('action.register.notFound'),
        icon: Icons.event_busy_outlined,
        message: context.tr('action.detail.notFound'),
      );
    }

    // Registration is not offered for full, running, or finished activities.
    // A block detected at confirm time keeps the user on the review step so the
    // message and the way back stay in context.
    if (!_alreadyRegistered &&
        _blocked == null &&
        !item.canRegisterAt(_now)) {
      return _UnavailableBody(full: item.isFull, onBack: _leave);
    }

    return Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: ListView(
            key: const ValueKey('action.register.content'),
            padding: const EdgeInsets.all(16),
            children: [
              StepIndicator(
                labels: [
                  context.tr('action.register.step.equipment'),
                  context.tr('action.register.step.participant'),
                  context.tr('action.register.step.review'),
                  context.tr('action.register.step.success'),
                ],
                current: _step - 1,
              ),
              const SizedBox(height: 20),
              if (_step == _successStep)
                _SuccessStep(item: item)
              else ...[
                _ActivitySummaryCard(item: item, now: _now),
                const SizedBox(height: 20),
                if (_step == 1) _equipmentStep(context, item),
                if (_step == 2) _participantStep(context),
                if (_step == 3) _reviewStep(context, item),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _equipmentStep(BuildContext context, ActionItem item) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('action.register.step.equipment.body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          icon: Icons.backpack_outlined,
          text: context.tr('action.detail.equipment'),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr('action.register.equipmentIntro'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        ActionEquipmentList(items: item.equipment),
        if (_equipmentRequired) ...[
          const SizedBox(height: 12),
          // Material (not a decorated Container) so the tile's ink splash stays
          // visible, as the framework requires.
          Material(
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.outline),
            ),
            child: CheckboxListTile(
              key: const ValueKey('action.register.equipmentAck'),
              value: _equipmentAcked,
              onChanged: (value) {
                setState(() => _equipmentAcked = value ?? false);
                _saveDraft();
              },
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                context.tr('action.register.equipmentReady'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (!_equipmentAcked) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('action.register.equipmentRequired'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _participantStep(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('action.register.step.participant.body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          icon: Icons.person_outline,
          text: context.tr('action.register.participantTitle'),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            children: [
              // Only what BlueTrack actually knows today: the account that is
              // signing up. Per-page participant columns are not specified in
              // this repository, so none are invented here.
              _DetailRow(
                label: context.tr('action.register.participantName'),
                value: _participantLabel(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('action.register.participantNote'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _reviewStep(BuildContext context, ActionItem item) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('action.register.step.review.body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          icon: Icons.fact_check_outlined,
          text: context.tr('action.register.reviewTitle'),
        ),
        if (_blocked != null) ...[
          const SizedBox(height: 12),
          _NoticeCard(
            key: const ValueKey('action.register.blocked'),
            icon: _blocked == _BlockReason.full
                ? Icons.groups_outlined
                : Icons.event_busy_outlined,
            title: context.tr(
              _blocked == _BlockReason.full
                  ? 'action.register.blockedFullTitle'
                  : 'action.register.blockedClosedTitle',
            ),
            body: context.tr(
              _blocked == _BlockReason.full
                  ? 'action.register.blockedFullBody'
                  : 'action.register.blockedClosedBody',
            ),
            onBack: _leave,
          ),
        ],
        if (_submitFailed) ...[
          const SizedBox(height: 12),
          _NoticeCard(
            key: const ValueKey('action.register.failed'),
            icon: Icons.error_outline,
            title: context.tr('action.register.failedTitle'),
            body: context.tr('action.register.failedBody'),
            onBack: null,
          ),
        ],
        const SizedBox(height: 12),
        _ReviewRow(
          label: context.tr('action.register.step.equipment'),
          value: context.tr(
            _equipmentAcked
                ? 'action.register.equipmentAcked'
                : 'action.register.equipmentNotAcked',
          ),
          onChange: _submitting ? null : () => _goToStep(1),
        ),
        // What the user committed to bring, repeated here so the review is
        // complete without going back to step 1.
        if (item.equipment.isNotEmpty) ...[
          const SizedBox(height: 10),
          ActionEquipmentList(items: item.equipment),
        ],
        Divider(height: 24, color: colors.outline),
        _ReviewRow(
          label: context.tr('action.register.participantName'),
          value: _participantLabel(context),
          onChange: _submitting ? null : () => _goToStep(2),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final item = _item!;
    final theme = Theme.of(context);

    if (_step == _successStep) {
      return _BottomBar(
        children: [
          PrimaryButton(
            key: const ValueKey('action.register.goToMyActions'),
            label: context.tr('action.register.goToMyActions'),
            onPressed: () {
              _draftStore.clear();
              context.go(Routes.myActions);
            },
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              key: const ValueKey('action.register.backToDetail'),
              onPressed: _leave,
              child: Text(context.tr('action.register.backToDetail')),
            ),
          ),
        ],
      );
    }

    if (_step == 1 || _step == 2) {
      return _BottomBar(
        children: [
          PrimaryButton(
            key: ValueKey('action.register.next.$_step'),
            label: context.tr('action.register.next'),
            onPressed: _step == 1 && !_canContinueFromEquipment
                ? null
                : () => _goToStep(_step + 1),
          ),
        ],
      );
    }

    final blocked = _blocked != null || !item.canRegisterAt(_now);
    return _BottomBar(
      children: [
        PrimaryButton(
          key: const ValueKey('action.register.confirmButton'),
          label: context.tr('action.register.confirm'),
          loading: _submitting,
          onPressed: blocked || _submitting ? null : _confirm,
        ),
        if (blocked) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              key: const ValueKey('action.register.blockedBack'),
              onPressed: _leave,
              child: Text(
                context.tr('action.register.back'),
                style: theme.textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact activity summary reused by steps 1, 2 and 3.
class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({required this.item, required this.now});

  final ActionItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final remaining = (item.quota - item.registered).clamp(0, item.quota);
    final quota = remaining > 0
        ? context.tr('action.detail.quotaRemaining', {
            'joined': '${item.registered}',
            'total': '${item.quota}',
            'remaining': '$remaining',
          })
        : context.tr('action.detail.quotaFull', {
            'joined': '${item.registered}',
            'total': '${item.quota}',
          });

    return Container(
      key: const ValueKey('action.register.summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('action.register.summary'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionStatusChip(status: item.statusAt(now)),
              _SummaryLine(
                icon: Icons.calendar_today_outlined,
                text: Formatters.date(item.startsAt, lang),
              ),
              _SummaryLine(
                icon: Icons.schedule_outlined,
                text:
                    '${Formatters.time(item.startsAt, lang)} – '
                    '${Formatters.time(item.endsAt, lang)}',
              ),
              _SummaryLine(
                icon: Icons.place_outlined,
                text: item.locationName,
              ),
              _SummaryLine(icon: Icons.groups_outlined, text: quota),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.onSurfaceVariant),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Review row with the "Ubah" link that jumps back to its step.
class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    required this.onChange,
  });

  final String label;
  final String value;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onChange,
          child: Text(context.tr('action.register.change')),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onBack,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onErrorContainer,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 4 — the result. Success is only reachable after a stored registration.
class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.item});

  final ActionItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    return Column(
      key: const ValueKey('action.register.step.success.body'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 26,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('action.register.successTitle'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('action.register.successBody'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              ActionStatusChip(
                key: const ValueKey('action.register.successStatus'),
                status: item.statusAt(DateTime.now()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          item.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _SummaryLine(
          icon: Icons.calendar_today_outlined,
          text: Formatters.date(item.startsAt, lang),
        ),
        const SizedBox(height: 6),
        _SummaryLine(
          icon: Icons.schedule_outlined,
          text:
              '${Formatters.time(item.startsAt, lang)} – '
              '${Formatters.time(item.endsAt, lang)}',
        ),
        const SizedBox(height: 6),
        _SummaryLine(icon: Icons.place_outlined, text: item.locationName),
        if (item.meetingPoint.isNotEmpty) ...[
          const SizedBox(height: 6),
          _SummaryLine(icon: Icons.flag_outlined, text: item.meetingPoint),
        ],
      ],
    );
  }
}

/// Shown instead of the wizard when the action no longer accepts sign-ups.
class _UnavailableBody extends StatelessWidget {
  const _UnavailableBody({required this.full, required this.onBack});

  final bool full;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey('action.register.unavailable'),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppDimens.cardRadius),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                full ? Icons.groups_outlined : Icons.event_busy_outlined,
                size: 28,
                color: colors.primary,
              ),
              const SizedBox(height: 10),
              Text(
                context.tr(
                  full
                      ? 'action.register.blockedFullTitle'
                      : 'action.register.blockedClosedTitle',
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  full
                      ? 'action.register.blockedFullBody'
                      : 'action.register.blockedClosedBody',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                key: const ValueKey('action.register.unavailableBack'),
                label: context.tr('action.register.back'),
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}
