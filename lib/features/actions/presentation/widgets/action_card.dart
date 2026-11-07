import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../domain/action_item.dart';
import 'action_cover_image.dart';

// Shared by the card, its skeleton-matching extent, and the metadata rows so
// the fixed grid cell and the content cannot drift apart.
const _titleFontSize = 14.0;
const _metaFontSize = 11.0;
const _contentTop = 8.0;
const _contentBottom = 10.0;

/// One action on the Action Agenda, sized for a two-column grid.
///
/// The card is presentation-only: [onTap] is supplied by the page so the card
/// can be tested without a router. The page maps it to the existing
/// `/actions/:id` detail route.
class ActionCard extends StatelessWidget {
  const ActionCard({super.key, required this.item, this.onTap});

  final ActionItem item;
  final VoidCallback? onTap;

  /// Height a grid cell needs for one [ActionCard] at [cardWidth].
  ///
  /// `GridView` needs a fixed main-axis extent. The calculation follows the
  /// card's own line heights (two-line title, two-line location, two-line
  /// organizer) and scales with the active text scaler, so large text grows
  /// the row instead of overflowing it.
  static double gridExtentFor(BuildContext context, double cardWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final titleLine = scaler.scale(_titleFontSize) * 1.25;
    final metaLine = scaler.scale(_metaFontSize) * 1.2;

    final contentHeight =
        _contentTop +
        _contentBottom +
        titleLine * 2 +
        6 + // title -> meta
        metaLine * 5 + // date, time, two-line location, quota
        9 + // gaps between the meta rows
        6 +
        1 +
        6 + // divider block
        math.max(16.0, metaLine * 2); // organizer can wrap to two lines

    return cardWidth * 3 / 4 + contentHeight + 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final date = Formatters.shortDate(item.startsAt, lang);
    final time =
        '${Formatters.time(item.startsAt, lang)}'
        ' – ${Formatters.time(item.endsAt, lang)}';
    final quota = context.tr('action.quota', {
      'joined': '${item.registered}',
      'total': '${item.quota}',
    });
    final titleHeight =
        MediaQuery.textScalerOf(context).scale(_titleFontSize) * 1.25 * 2;

    return Card(
      // Grid spacing owns the gaps; the default Card margin would add an
      // extra 4dp on every side and break the two-column rhythm.
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
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ActionCoverImage(imageAsset: item.imageAsset),
                  // Scrim keeps the type chip readable on bright photos.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    right: 8,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: _TypeChip(type: item.type),
                    ),
                  ),
                  if (item.isFull)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _FullChip(item: item),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                9,
                _contentTop,
                9,
                _contentBottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: titleHeight,
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: _titleFontSize,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Meta(icon: Icons.calendar_today_outlined, text: date),
                  const SizedBox(height: 3),
                  _Meta(icon: Icons.schedule_outlined, text: time),
                  const SizedBox(height: 3),
                  _Meta(
                    icon: Icons.place_outlined,
                    text: item.locationName,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 3),
                  _Meta(
                    icon: Icons.groups_outlined,
                    text: quota,
                    maxLines: 1,
                    weight: FontWeight.w600,
                    color: item.isFull ? colors.tertiary : colors.primary,
                  ),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: colors.outline),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metaIcon(context, Icons.account_balance_outlined),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.organizerName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _metaStyle(
                            context,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.organizerVerified) ...[
                        const SizedBox(width: 3),
                        const VerifiedBadge(compact: true),
                      ],
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

  TextStyle _metaStyle(
    BuildContext context, {
    FontWeight weight = FontWeight.w500,
  }) {
    return TextStyle(
      fontSize: _metaFontSize,
      fontWeight: weight,
      height: 1.2,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  Widget _metaIcon(BuildContext context, IconData icon) {
    return Icon(
      icon,
      size: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
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

/// Compact full-quota status over the cover. The organizer still sees the
/// complete explanation in the quota semantics below the image.
class _FullChip extends StatelessWidget {
  const _FullChip({required this.item});

  final ActionItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: context.tr('action.quota.full', {
        'joined': '${item.registered}',
        'total': '${item.quota}',
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: colors.tertiary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          context.tr('action.status.full'),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: colors.onTertiary,
          ),
        ),
      ),
    );
  }
}

/// Icon + compact value used for date, time, location, and quota.
class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    this.color,
    this.maxLines = 1,
    this.weight = FontWeight.w500,
  });

  final IconData icon;
  final String text;
  final Color? color;
  final int maxLines;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colors.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: effectiveColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _metaFontSize,
              fontWeight: weight,
              height: 1.2,
              color: effectiveColor,
            ),
          ),
        ),
      ],
    );
  }
}
