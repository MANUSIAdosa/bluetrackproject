import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
import '../../../shared/widgets/verified_badge.dart';
import '../data/action_participation_store.dart';
import '../data/action_repository.dart';
import '../domain/action_item.dart';
import 'widgets/action_cover_image.dart';
import 'widgets/action_mini_map.dart';

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
  bool _registering = false;

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
      appBar: AppBar(title: Text(context.tr('detail.action'))),
      body: _buildBody(context),
      bottomNavigationBar: item == null
          ? null
          : _RegisterBar(
              label: _ctaLabel(context, item),
              registered: _registered,
              loading: _registering,
              onPressed: _registered || !item.canRegisterAt(_now)
                  ? null
                  : _handleRegister,
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
    if (_registered) return context.tr('action.detail.registered');

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

  Future<void> _handleRegister() async {
    final item = _item;
    if (item == null || _registering || _registered) return;

    if (!AuthController.instance.signedIn) {
      final redirect = Uri.encodeComponent(Routes.actionDetailUrl(item.id));
      await context.push('${Routes.auth}?redirect=$redirect');
      return;
    }

    if (!item.canRegisterAt(_now)) return;

    final confirmed = await _showConfirmation(item);
    if (!mounted || !confirmed) return;

    // Re-check after the sheet closes: the date can change while the sheet is
    // open and the button must never allow a duplicate registration.
    if (_registering || _registered || !item.canRegisterAt(_now)) return;

    setState(() => _registering = true);
    try {
      await _repository.registerAction(item.id);
      await _participationStore.setRegistered(item.id, true);
      if (!mounted) return;
      setState(() {
        _registered = true;
        _registering = false;
      });
      _showSnack(context.tr('action.detail.registerSuccess'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _registering = false);
      _showSnack(context.tr('action.detail.registerFailed'), error: true);
    }
  }

  Future<bool> _showConfirmation(ActionItem item) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final lang = Localizations.localeOf(sheetContext).languageCode;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('action.detail.confirmTitle'),
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('action.detail.confirmBody'),
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _SheetInfo(
                  icon: Icons.calendar_today_outlined,
                  text: Formatters.date(item.startsAt, lang),
                ),
                const SizedBox(height: 6),
                _SheetInfo(
                  icon: Icons.schedule_outlined,
                  text:
                      '${Formatters.time(item.startsAt, lang)} – '
                      '${Formatters.time(item.endsAt, lang)}',
                ),
                const SizedBox(height: 6),
                _SheetInfo(
                  icon: Icons.place_outlined,
                  text: item.locationName,
                ),
                const SizedBox(height: 6),
                _SheetInfo(
                  icon: Icons.groups_outlined,
                  text: context.tr('action.quota', {
                    'joined': '${item.registered}',
                    'total': '${item.quota}',
                  }),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: context.tr('action.detail.confirm'),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: Text(context.tr('common.cancel')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
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
class _RegisterBar extends StatelessWidget {
  const _RegisterBar({
    required this.label,
    required this.registered,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool registered;
  final bool loading;
  final VoidCallback? onPressed;

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
          child: PrimaryButton(
            key: _registerButtonKey,
            label: label,
            icon: registered ? Icons.check_circle_outline : null,
            loading: loading,
            onPressed: onPressed,
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
    final quota = context.tr('action.quota', {
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
              _ActionCover(item: item),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        _StatusChip(status: item.statusAt(now)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.groups_outlined,
                              size: 17,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              quota,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                    const SizedBox(height: 20),
                    _InfoCard(item: item, lang: lang),
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
                    if (item.equipment.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionTitle(
                        icon: Icons.backpack_outlined,
                        text: context.tr('action.detail.equipment'),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final equipment in item.equipment)
                            _EquipmentChip(label: equipment),
                        ],
                      ),
                    ],
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ActionStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (key, background, foreground) = switch (status) {
      ActionStatus.open => (
        'action.status.open',
        colors.primary,
        colors.onPrimary,
      ),
      ActionStatus.full => (
        'action.status.full',
        colors.tertiary,
        colors.onTertiary,
      ),
      ActionStatus.ended => (
        'action.status.ended',
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };

    return Container(
      key: const ValueKey('action.detail.status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.tr(key),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: foreground,
        ),
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

class _EquipmentChip extends StatelessWidget {
  const _EquipmentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 14, color: colors.primary),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 96,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
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

class _SheetInfo extends StatelessWidget {
  const _SheetInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
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
