import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/state/app_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/category_icon.dart';
import '../../domain/explore_map_data.dart';
import 'condition_label.dart';

/// The filters Jelajahi applies to both the list and the map.
///
/// `'semua'` / [DistanceBand.semua] / `null` mean "no filter", so the category
/// selector, the search field and the sheet all write into the same selection.
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

/// Opens the filter sheet and returns the new selection, or null when the user
/// dismisses the sheet without applying anything.
///
/// [countFor] receives the draft selection so the footer can preview how many
/// projects the draft would keep; the page owns that calculation, so the sheet
/// never duplicates the filtering rules.
Future<ExploreFilterSelection?> showExploreFilterSheet(
  BuildContext context, {
  required List<String> categoryIds,
  required ExploreFilterSelection selection,
  required String userLocationLabel,
  int Function(ExploreFilterSelection draft)? countFor,
}) => showModalBottomSheet<ExploreFilterSelection>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: AppColors.surface,
  builder: (_) => _ExploreFilterSheet(
    categoryIds: categoryIds,
    selection: selection,
    userLocationLabel: userLocationLabel,
    countFor: countFor,
  ),
);

class _ExploreFilterSheet extends StatefulWidget {
  const _ExploreFilterSheet({
    required this.categoryIds,
    required this.selection,
    required this.userLocationLabel,
    this.countFor,
  });

  final List<String> categoryIds;
  final ExploreFilterSelection selection;
  final String userLocationLabel;
  final int Function(ExploreFilterSelection draft)? countFor;

  @override
  State<_ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<_ExploreFilterSheet> {
  late ExploreFilterSelection _draft = widget.selection;

  @override
  Widget build(BuildContext context) {
    final count = widget.countFor?.call(_draft);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        key: const ValueKey('explore.filter.sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('p03_filter_title'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('explore.filter.close'),
                    tooltip: context.tr('p03_filter_close'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterGroup(
                      title: context.tr('p03_filter_category'),
                      helper: context.tr('p03_filter_category_helper'),
                      children: [
                        for (final id in widget.categoryIds)
                          _FilterOption(
                            key: ValueKey('explore.filter.category.$id'),
                            label: context.tr('cat.$id'),
                            selected: _draft.category == id,
                            leading: id == 'semua'
                                ? const Icon(
                                    Icons.grid_view_rounded,
                                    size: 18,
                                    color: AppColors.ocean,
                                  )
                                : CategoryIcon(category: id, size: 18),
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(category: id),
                            ),
                          ),
                      ],
                    ),
                    _FilterGroup(
                      title: context.tr('p03_filter_distance'),
                      helper: context.tr('p03_distance_reference', {
                        'place': widget.userLocationLabel,
                      }),
                      children: [
                        for (final band in DistanceBand.values)
                          _FilterOption(
                            key: ValueKey(
                              'explore.filter.distance.${band.name}',
                            ),
                            label: context.tr('p03_distance_${band.name}'),
                            selected: _draft.distance == band,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(distance: band),
                            ),
                          ),
                      ],
                    ),
                    _FilterGroup(
                      title: context.tr('p03_filter_condition'),
                      helper: context.tr('p03_filter_condition_helper'),
                      children: [
                        _FilterOption(
                          key: const ValueKey('explore.filter.condition.semua'),
                          label: context.tr('p03_filter_all'),
                          selected: _draft.condition == null,
                          onTap: () => setState(
                            () =>
                                _draft = _draft.copyWith(clearCondition: true),
                          ),
                        ),
                        for (final condition in ProjectCondition.values)
                          _FilterOption(
                            key: ValueKey(
                              'explore.filter.condition.${condition.id}',
                            ),
                            label: condition.label(context),
                            selected: _draft.condition == condition,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(
                                condition: condition,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // No connectivity package exists, so the offline state can
                    // only be set by hand. The switch is debug-only.
                    if (kDebugMode) ...[
                      const SizedBox(height: 4),
                      const _OfflineDebugSwitch(),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton(
                      key: const ValueKey('explore.filter.reset'),
                      onPressed: () =>
                          setState(() => _draft = ExploreFilterSelection.none),
                      child: Text(context.tr('p03_filter_reset')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: FilledButton(
                      key: const ValueKey('explore.filter.apply'),
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: Text(
                        count == null
                            ? context.tr('p03_filter_apply')
                            : context.tr('p03_filter_result_count', {
                                'n': '$count',
                              }),
                      ),
                    ),
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

/// One filter dimension: a titled card so the groups never blur together.
class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.children,
    this.helper,
  });

  final String title;
  final String? helper;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (helper != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    helper!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Radio-style row: one tap target per option, no chip semantics.
class _FilterOption extends StatelessWidget {
  const _FilterOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.ocean : AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
                color: selected ? AppColors.ocean : AppColors.inactiveTab,
              ),
            ],
          ),
        ),
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
