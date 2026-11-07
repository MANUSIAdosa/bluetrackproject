import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

/// Prominent, vertical equipment checklist used by the action detail and the
/// registration wizard.
///
/// The action model only stores a flat list of item names, so the list is
/// rendered exactly as it arrives: no "required by you" versus "provided by the
/// organizer" split is invented here (that needs a schema change — see the
/// report). A tick icon plus the item name carries the meaning; colour is only
/// decoration.
class ActionEquipmentList extends StatelessWidget {
  const ActionEquipmentList({
    super.key,
    required this.items,
    this.emptyLabelKey = 'action.detail.equipmentNone',
  });

  final List<String> items;

  /// Localization key used when the action lists no equipment.
  final String emptyLabelKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Container(
        key: const ValueKey('action.equipment.empty'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          context.tr(emptyLabelKey),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('action.equipment.list'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 48,
                endIndent: 14,
                color: colors.primary.withValues(alpha: 0.2),
              ),
            _EquipmentRow(label: items[i], index: i),
          ],
        ],
      ),
    );
  }
}

class _EquipmentRow extends StatelessWidget {
  const _EquipmentRow({required this.label, required this.index});

  final String label;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: ValueKey('action.equipment.item.$index'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
