import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../data/action_participation_store.dart';
import '../data/action_repository.dart';
import '../domain/action_item.dart';
import 'widgets/action_cover_image.dart';
import 'widgets/action_equipment_list.dart';
import 'widgets/action_mini_map.dart';
import 'widgets/action_status_chip.dart';

const _registerButtonKey = ValueKey('action.detail.registerButton');
const _reminderSwitchKey = ValueKey('action.detail.reminderSwitch');

/// P04-family detail page for one action on the Action Agenda.
///
/// The page owns the detail request, the local registration/reminder state and
/// the registration interaction. It is pushed on the root navigator by
/// `/actions/:id`, so the bottom CTA can stay pinned above the phone's safe
/// area without the shell navigation bar.
class ActionDetailPage extends StatefulWidget {
  const ActionDetailPage({
    super.key,
    required this.actionId,
    this.repository,
    this.participationStore,
    this.tileProvider,
    this.now,
  });

  final String actionId;

  /// Test/demo overrides. The router keeps constructing the page with only
  /// [actionId].
  final ActionRepository? repository;
  final ActionParticipationStore? participationStore;

  /// Test seam for the mini map's network tiles.
  final TileProvider? tileProvider;

  /// Test seam for date-based status and registration validation.
  final DateTime Function()? now;

  @override
  State<ActionDetailPage> createState() => _ActionDetailPageState();
}

class _ActionDetailPageState extends State<ActionDetailPage> {
  late final ActionRepository _repository =
      widget.repository ?? const MockActionRepository();
  late final ActionParticipationStore _participationStore =
      widget.participationStore ?? const PrefsActionParticipationStore();

  ActionItem? _item;
  bool _registered = false;
  bool _reminder = false;
  bool _loading = true;
  bool _error = false;
  bool _cancelling = false;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _item = null;
      _registered = false;
      _reminder = false;
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
      setState(() => _loading = false);
      return;
    }

    // Participation is local-only in the mock. A storage failure must not hide
    // the activity itself, so fall back to the default (not registered) state.
    var participation = const ActionParticipation();
    try {
      participation = await _participationStore.load(item.id);
    } catch (_) {
      participation = const ActionParticipation();
    }

    if (!mounted) return;
    setState(() {
      _item = item;
      _registered = participation.registered;
      _reminder = participation.reminder;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('detail.action')),
        // The page is normally pushed from the agenda, but it is also a
        // deep-link target. Fall back to the agenda when there is no stack.
        leading: BackButton(
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              context.go(Routes.actionAgenda);
            }
          },
        ),
      ),
      body: _buildBody(context),
      bottomNavigationBar: item == null
          ? null
          : _RegisterBar(
              registered: _registered,
              busy: _cancelling,
              registerLabel: _ctaLabel(context, item),
              registerEnabled: item.canRegisterAt(_now),
              onRegister: _openRegistration,
              onCancel: _confirmCancel,
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        key: ValueKey('action.detail.loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (_error) {
      return ErrorState(
        key: const ValueKey('action.detail.error'),
        message: context.tr('action.detail.loadFailed'),
        onRetry: _load,
      );
    }

    final item = _item;
    if (item == null) {
      return EmptyState(
        key: const ValueKey('action.detail.notFound'),
        icon: Icons.event_busy_outlined,
        message: context.tr('action.detail.notFound'),
      );
    }

    return _ActionDetailContent(
      item: item,
      now: _now,
      registered: _registered,
      reminder: _reminder,
      tileProvider: widget.tileProvider,
      onReminderChanged: _setReminder,
      onOpenOrganizer: _openOrganizer,
    );
  }

  String _ctaLabel(BuildContext context, ActionItem item) {
    final status = item.statusAt(_now);
    if (status == ActionStatus.ended) {
      return context.tr('action.status.ended');
    }
    if (status == ActionStatus.full) {
      return context.tr('action.status.full');
    }
    if (!item.canRegisterAt(_now)) {
      return context.tr('action.detail.registrationClosed');
    }
    return context.tr('action.detail.register');
  }

  /// Opens the four-step registration wizard, then refreshes so the card state
  /// and the participant count reflect what was stored.
  Future<void> _openRegistration() async {
    final item = _item;
    if (item == null || _registered) return;
    if (!item.canRegisterAt(_now)) return;

    await context.push(Routes.actionRegisterUrl(item.id));
    if (!mounted) return;
    await _load();
  }

  /// Cancels the registration after an explicit confirmation, then refreshes
  /// the participant count from the data source.
  Future<void> _confirmCancel() async {
    final item = _item;
    if (item == null || _cancelling) return;

    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('action.detail.cancelDialog'),
        title: Text(context.tr('action.detail.cancelTitle')),
        content: Text(context.tr('action.detail.cancelBody')),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: AppDimens.dialogActionMinSize,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('action.detail.cancelKeep')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: AppDimens.dialogActionMinSize,
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('action.detail.cancelConfirm')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      await _repository.cancelRegistration(item.id);
      await _participationStore.setRegistered(item.id, false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      _showSnack(context.tr('action.detail.cancelFailed'), error: true);
      return;
    }

    if (!mounted) return;
    setState(() => _cancelling = false);
    // The refreshed item carries the released seat; the status banner follows.
    await _load();
    if (!mounted) return;
    _showSnack(context.tr('action.detail.cancelSuccess'));
  }

  Future<void> _setReminder(bool enabled) async {
    final item = _item;
    if (item == null || !_registered) return;

    final previous = _reminder;
    setState(() => _reminder = enabled);
    try {
      await _participationStore.setReminder(item.id, enabled);
      if (!mounted) return;
      _showSnack(
        context.tr(
          enabled
              ? 'action.detail.reminderEnabled'
              : 'action.detail.reminderDisabled',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _reminder = previous);
      _showSnack(context.tr('common.error'), error: true);
    }
  }

  void _openOrganizer() {
    final organizerId = _item?.organizerId;
    if (organizerId == null || organizerId.isEmpty) return;
    context.push(Routes.orgDetailUrl(organizerId));
  }

  void _showSnack(String message, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: error ? TextStyle(color: colors.onError) : null,
          ),
          backgroundColor: error ? colors.error : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// Pinned registration CTA above the phone safe area.
///
/// While registered the bar offers cancellation instead of a disabled
/// "Terdaftar" button: the status itself is displayed in the page content, so
/// the bar keeps a single, honest action.
class _RegisterBar extends StatelessWidget {
  const _RegisterBar({
    required this.registered,
    required this.busy,
    required this.registerLabel,
    required this.registerEnabled,
    required this.onRegister,
    required this.onCancel,
  });

  final bool registered;
  final bool busy;
  final String registerLabel;
  final bool registerEnabled;
  final VoidCallback onRegister;
  final VoidCallback onCancel;

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
          child: registered
              ? SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: _registerButtonKey,
                    onPressed: busy ? null : onCancel,
                    icon: const Icon(Icons.cancel_outlined),
                    label: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('action.detail.cancel')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                )
              : PrimaryButton(
                  key: _registerButtonKey,
                  label: registerLabel,
                  icon: null,
                  loading: busy,
                  onPressed: registerEnabled ? onRegister : null,
                ),
        ),
      ),
    );
  }
}

/// Scrollable detail content. Kept separate from the state object so the body
/// can be tested with fixed status/registration values.
class _ActionDetailContent extends StatelessWidget {
  const _ActionDetailContent({
    required this.item,
    required this.now,
    required this.registered,
    required this.reminder,
    required this.onReminderChanged,
    required this.onOpenOrganizer,
    this.tileProvider,
  });

  final ActionItem item;
  final DateTime now;
  final bool registered;
  final bool reminder;
  final ValueChanged<bool> onReminderChanged;
  final VoidCallback onOpenOrganizer;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
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

    return Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: ListView(
            key: const ValueKey('action.detail.content'),
            padding: EdgeInsets.zero,
            children: [
              // 1. Photo.
              _ActionCover(item: item),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Title, activity status, the user's own registration
                    //    status, and the remaining quota.
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ActionStatusChip(
                          key: const ValueKey('action.detail.status'),
                          status: item.statusAt(now),
                        ),
                        if (registered)
                          _RegisteredChip(
                            key: const ValueKey('action.detail.registeredChip'),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.groups_outlined,
                              size: 17,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                quota,
                                key: const ValueKey('action.detail.quota'),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // 3. Date, time, location and meeting point.
                    const SizedBox(height: 20),
                    _InfoCard(item: item, lang: lang),
                    // 4. Needed equipment — promoted above the description so
                    //    it is found before registering, not after the map.
                    const SizedBox(height: 20),
                    _SectionTitle(
                      icon: Icons.backpack_outlined,
                      text: context.tr('action.detail.equipment'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('action.detail.equipmentIntro'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ActionEquipmentList(items: item.equipment),
                    // 5. Description.
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionTitle(
                        icon: Icons.notes_outlined,
                        text: context.tr('action.detail.description'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.description,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              height: 1.55,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                    // 6. Map.
                    const SizedBox(height: 20),
                    _SectionTitle(
                      icon: Icons.map_outlined,
                      text: context.tr('action.detail.map'),
                    ),
                    const SizedBox(height: 8),
                    ActionMiniMap(
                      latitude: item.latitude,
                      longitude: item.longitude,
                      tileProvider: tileProvider,
                    ),
                    // 7. Organizer.
                    const SizedBox(height: 20),
                    _SectionTitle(
                      icon: Icons.account_balance_outlined,
                      text: context.tr('action.detail.organizer'),
                    ),
                    const SizedBox(height: 8),
                    _OrganizerCard(
                      item: item,
                      onTap: item.organizerId == null ||
                              item.organizerId!.isEmpty
                          ? null
                          : onOpenOrganizer,
                    ),
                    // 8. Reminder for registered participants.
                    if (registered) ...[
                      const SizedBox(height: 16),
                      _ReminderCard(
                        value: reminder,
                        onChanged: onReminderChanged,
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCover extends StatelessWidget {
  const _ActionCover({required this.item});

  final ActionItem item;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ActionCoverImage(imageAsset: item.imageAsset, iconSize: 48),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [Color(0x4D000000), Colors.transparent],
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: Align(
              alignment: Alignment.topLeft,
              child: _TypeChip(type: item.type),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final ActionType type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_actionTypeIcon(type), size: 14, color: colors.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              context.tr('action.type.${type.id}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});

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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.item, required this.lang});

  final ActionItem item;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rows = <Widget>[
      _InfoRow(
        icon: Icons.calendar_today_outlined,
        label: context.tr('action.detail.date'),
        value: Formatters.date(item.startsAt, lang),
      ),
      _InfoRow(
        icon: Icons.schedule_outlined,
        label: context.tr('action.detail.time'),
        value:
            '${Formatters.time(item.startsAt, lang)} – '
            '${Formatters.time(item.endsAt, lang)}',
      ),
      _InfoRow(
        icon: Icons.place_outlined,
        label: context.tr('action.detail.location'),
        value: item.locationName,
      ),
      if (item.meetingPoint.isNotEmpty)
        _InfoRow(
          icon: Icons.flag_outlined,
          label: context.tr('action.detail.meetingPoint'),
          value: item.meetingPoint,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 20, color: colors.outline),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: colors.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
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
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The user's own registration status. Shown next to the activity status so the
/// two read together instead of contradicting each other.
class _RegisteredChip extends StatelessWidget {
  const _RegisteredChip({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 13,
            color: colors.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.tr('action.status.registered'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizerCard extends StatelessWidget {
  const _OrganizerCard({required this.item, this.onTap});

  final ActionItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tappable = onTap != null;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: BorderSide(color: colors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('action.detail.organizer'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  _initials(item.organizerName),
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.organizerName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (item.organizerVerified) ...[
                          const SizedBox(width: 6),
                          const VerifiedBadge(compact: true),
                        ],
                      ],
                    ),
                    if (tappable) ...[
                      const SizedBox(height: 2),
                      Text(
                        context.tr('action.detail.viewOrganizer'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (tappable)
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('action.detail.reminder'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('action.detail.reminderBody'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: _reminderSwitchKey,
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

IconData _actionTypeIcon(ActionType type) {
  return switch (type) {
    ActionType.beachCleanup => Icons.cleaning_services_outlined,
    ActionType.coralRestoration => Icons.water_outlined,
    ActionType.mangrovePlanting => Icons.park_outlined,
    ActionType.wildlifeMonitoring => Icons.pets_outlined,
    ActionType.education => Icons.school_outlined,
  };
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}
