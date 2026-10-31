import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/state/app_state.dart';
import '../../../../shared/widgets/category_icon.dart';
import '../../domain/explore_map_data.dart';
import 'condition_label.dart';

/// The filters Jelajahi applies to both the list and the map.
///
/// `'semua'` / [DistanceBand.semua] / `null` mean "no filter", so the chip row,
/// the search field and the sheet all write into the same selection.
class ExploreFilterSelection {
  const ExploreFilterSelection({
    this.category = 'semua',
    this.distance = DistanceBand.semua,
    this.condition,
  });

  final String category;
  final DistanceBand distance;
  final ProjectCondition? condition;

  static const ExploreFilterSelection none = ExploreFilterSelection();

  /// Number of groups that are narrowing the results — badged on the filter
  /// button so an active filter is visible without opening the sheet.
  int get activeCount =>
      (category == 'semua' ? 0 : 1) +
      (distance == DistanceBand.semua ? 0 : 1) +
      (condition == null ? 0 : 1);

  ExploreFilterSelection copyWith({
    String? category,
    DistanceBand? distance,
    ProjectCondition? condition,
    bool clearCondition = false,
  }) => ExploreFilterSelection(
    category: category ?? this.category,
    distance: distance ?? this.distance,
    condition: clearCondition ? null : (condition ?? this.condition),
  );
}

/// Localized name of a condition, shared by the sheet and the map sheets.
/// Opens the filter sheet and returns the new selection, or null when the user
/// dismisses the sheet without applying anything.
Future<ExploreFilterSelection?> showExploreFilterSheet(
  BuildContext context, {
  required List<String> categoryIds,
  required ExploreFilterSelection selection,
  required String userLocationLabel,
}) => showModalBottomSheet<ExploreFilterSelection>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ExploreFilterSheet(
    categoryIds: categoryIds,
    selection: selection,
    userLocationLabel: userLocationLabel,
  ),
);

class _ExploreFilterSheet extends StatefulWidget {
  const _ExploreFilterSheet({
    required this.categoryIds,
    required this.selection,
    required this.userLocationLabel,
  });

  final List<String> categoryIds;
  final ExploreFilterSelection selection;
  final String userLocationLabel;

  @override
  State<_ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<_ExploreFilterSheet> {
  late ExploreFilterSelection _draft = widget.selection;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SectionTitle(context.tr('p03_filter_category')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in widget.categoryIds)
                    ChoiceChip(
                      avatar: id == 'semua'
                          ? null
                          : CategoryIcon(category: id, size: 18),
                      label: Text(context.tr('cat.$id')),
                      selected: _draft.category == id,
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _draft = _draft.copyWith(category: id)),
                    ),
                ],
              ),
              _SectionTitle(
                context.tr('p03_filter_distance'),
                subtitle: context.tr('p03_distance_reference', {
                  'place': widget.userLocationLabel,
                }),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final band in DistanceBand.values)
                    ChoiceChip(
                      label: Text(context.tr('p03_distance_${band.name}')),
                      selected: _draft.distance == band,
                      showCheckmark: false,
                      onSelected: (_) => setState(
                        () => _draft = _draft.copyWith(distance: band),
                      ),
                    ),
                ],
              ),
              _SectionTitle(context.tr('p03_filter_condition')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(context.tr('p03_distance_semua')),
                    selected: _draft.condition == null,
                    showCheckmark: false,
                    onSelected: (_) => setState(
                      () => _draft = _draft.copyWith(clearCondition: true),
                    ),
                  ),
                  for (final condition in ProjectCondition.values)
                    ChoiceChip(
                      label: Text(condition.label(context)),
                      selected: _draft.condition == condition,
                      showCheckmark: false,
                      onSelected: (_) => setState(
                        () => _draft = _draft.copyWith(condition: condition),
                      ),
                    ),
                ],
              ),
              // No connectivity package exists, so the offline state can only be
              // set by hand. The switch is debug-only: it never ships.
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                const _OfflineDebugSwitch(),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(ExploreFilterSelection.none),
                      child: Text(context.tr('p03_filter_reset')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: Text(context.tr('p03_filter_apply')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
        ],
      ),
    );
  }
}

/// Debug-only offline override. Flips the app-wide [OfflineController] so the
/// offline banner and the saved-only list can be demoed without disconnecting
/// the device; the next real connectivity change still updates the controller.
class _OfflineDebugSwitch extends StatelessWidget {
  const _OfflineDebugSwitch();

  @override
  Widget build(BuildContext context) {
    final offline = OfflineController.instance;
    return ListenableBuilder(
      listenable: offline,
      builder: (context, _) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: offline.offline,
        title: Text(context.tr('p03_simulate_offline')),
        onChanged: (value) => offline.setOffline(value),
      ),
    );
  }
}
