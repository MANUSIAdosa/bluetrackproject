import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/action_item.dart';

/// Icon that carries the same meaning as the status text, so the status never
/// depends on colour alone.
IconData actionStatusIcon(ActionStatus status) {
  return switch (status) {
    ActionStatus.open => Icons.event_available_outlined,
    ActionStatus.full => Icons.groups_outlined,
    ActionStatus.ongoing => Icons.play_circle_outline,
    ActionStatus.ended => Icons.event_busy_outlined,
  };
}

/// Localization key of a status label. The enum name is the stable key suffix,
/// so the agenda card and the detail page always show the same wording.
String actionStatusLabelKey(ActionStatus status) =>
    'action.status.${status.name}';

/// Shared activity-status pill: icon + text, used by the agenda card and the
/// action detail header so both surfaces cannot drift apart.
class ActionStatusChip extends StatelessWidget {
  const ActionStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final ActionStatus status;

  /// Card-sized pill; the detail header uses the regular size.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      ActionStatus.open => (colors.primary, colors.onPrimary),
      ActionStatus.full => (colors.tertiary, colors.onTertiary),
      ActionStatus.ongoing => (colors.secondary, colors.onSecondary),
      ActionStatus.ended => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            actionStatusIcon(status),
            size: compact ? 11 : 13,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.tr(actionStatusLabelKey(status)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
                height: 1.15,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
