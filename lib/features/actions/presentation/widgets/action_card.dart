import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../domain/action_item.dart';
import 'action_cover_image.dart';
import 'action_status_chip.dart';

const _titleFontSize = 16.0;
const _metaFontSize = 12.0;

/// One action on the Action Agenda.
///
/// Three stacked parts: the 16:9 cover with the type, activity status and (for
/// the user's own registrations) the Terdaftar badge, the readable body (title,
/// schedule, location, organizer, quota), and the action hint pinned to the
/// bottom.
///
/// The card takes the height it is given and lets the body absorb the surplus,
/// so every card in a row ends up the same height with its hint aligned at the
/// bottom. The page provides that bounded height with an `IntrinsicHeight` row
/// — the card never computes a cell extent itself.
///
/// The card is presentation-only: [onTap] is supplied by the page so the card
/// can be tested without a router. The page maps it to the existing
/// `/actions/:id` detail route.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.item,
    this.onTap,
    this.registered = false,
    this.now,
  });

  final ActionItem item;
  final VoidCallback? onTap;

  /// Whether the signed-in user is registered for this action. Comes from the
  /// participation store — never hardcoded here.
  final bool registered;

  /// Test/clock seam; defaults to [DateTime.now].
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final current = now ?? DateTime.now();

    final status = item.statusAt(current);
    final canRegister = !registered && item.canRegisterAt(current);
    // Full and finished activities are dimmed a little; the card stays
    // tappable and every label stays readable.
    final dimmed = status == ActionStatus.full || status == ActionStatus.ended;

    final remaining = (item.quota - item.registered).clamp(0, item.quota);
    final quota = remaining > 0
        ? context.tr('action.card.quota', {
            'joined': '${item.registered}',
            'total': '${item.quota}',
            'remaining': '$remaining',
          })
        : context.tr('action.card.quotaFull', {
            'joined': '${item.registered}',
            'total': '${item.quota}',
          });

    final metaStyle = TextStyle(
      fontSize: _metaFontSize,
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: colors.onSurfaceVariant,
    );

    return Card(
      margin: EdgeInsets.zero,
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: BorderSide(color: colors.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Top: cover, type and activity status -----------------------
            AspectRatio(
              key: ValueKey('actionCard.${item.id}.cover'),
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: dimmed ? 0.72 : 1,
                    child: ActionCoverImage(imageAsset: item.imageAsset),
                  ),
                  // Scrim keeps the chips readable on bright photos.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x4D000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    right: 8,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(child: _TypeChip(type: item.type)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: ActionStatusChip(
                              status: status,
                              compact: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The user's own registration lives on the photo, mirroring
                  // the type/status pills, so both states stay visible without
                  // competing for the same corner.
                  if (registered)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      right: 8,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: _RegisteredBadge(),
                      ),
                    ),
                ],
              ),
            ),
            // --- Middle: readable details (absorbs surplus height) ---------
            Expanded(
              child: Opacity(
                opacity: dimmed ? 0.78 : 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: _titleFontSize,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _Meta(
                        icon: Icons.calendar_today_outlined,
                        text: Formatters.shortDate(item.startsAt, lang),
                        style: metaStyle,
                      ),
                      const SizedBox(height: 4),
                      _Meta(
                        icon: Icons.schedule_outlined,
                        text:
                            '${Formatters.time(item.startsAt, lang)}'
                            ' – ${Formatters.time(item.endsAt, lang)}',
                        style: metaStyle,
                      ),
                      const SizedBox(height: 4),
                      _Meta(
                        icon: Icons.place_outlined,
                        text: item.locationName,
                        style: metaStyle,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      _Meta(
                        icon: Icons.account_balance_outlined,
                        text: item.organizerName,
                        style: metaStyle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        trailing: item.organizerVerified
                            ? const VerifiedBadge(compact: true)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      _Meta(
                        icon: Icons.groups_outlined,
                        text: quota,
                        style: metaStyle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: remaining == 0
                              ? colors.tertiary
                              : colors.primary,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
            // --- Bottom: what tapping the card does --------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(height: 1, color: colors.outline),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        canRegister
                            ? Icons.how_to_reg_outlined
                            : Icons.article_outlined,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.tr(
                            canRegister
                                ? 'action.card.viewAndRegister'
                                : 'action.card.viewDetail',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small type label over the cover.
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final ActionType type;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
          Icon(_iconFor(type), size: 11, color: colors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.tr('action.type.${type.id}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ActionType type) {
    return switch (type) {
      ActionType.beachCleanup => Icons.cleaning_services_outlined,
      ActionType.coralRestoration => Icons.water_outlined,
      ActionType.mangrovePlanting => Icons.park_outlined,
      ActionType.wildlifeMonitoring => Icons.pets_outlined,
      ActionType.education => Icons.school_outlined,
    };
  }
}

/// Marks an action the user already registered for. This is the user's own
/// registration state, shown separately from the activity status so the two
/// never contradict each other (e.g. "Terdaftar" on an activity that has since
/// become "Penuh").
class _RegisteredBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('actionCard.registered'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
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
          Icon(
            Icons.check_circle_outline,
            size: 11,
            color: colors.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.tr('action.status.registered'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
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

/// Icon + value row used for date, time, location, organizer, and quota.
class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    required this.style,
    this.maxLines = 1,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final TextStyle style;
  final int maxLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: style.color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing!,
        ],
      ],
    );
  }
}
