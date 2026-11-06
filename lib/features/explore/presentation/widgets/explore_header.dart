import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/category_icon.dart';
import '../../../../shared/widgets/notification_bell.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../domain/explore_map_data.dart';
import 'condition_label.dart';
import 'explore_list_widgets.dart';
import 'filter_sheet.dart';

/// Compact gradient header of Jelajahi: identity, saved scope, search and
/// filter.
///
/// The header is intentionally short: saved, search and filter are primary
/// actions and stay reachable, while the view switch, category rail and active
/// filter tokens live below it so they never eat the viewport.
class ExploreHeader extends StatelessWidget {
  const ExploreHeader({
    super.key,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.filterActiveCount,
    required this.onFilterPressed,
    required this.saved,
    required this.savedCount,
    required this.onSavedChanged,
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final int filterActiveCount;
  final VoidCallback onFilterPressed;
  final bool saved;
  final int savedCount;
  final ValueChanged<bool> onSavedChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('explore.header'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.oceanDeep, AppColors.ocean, AppColors.teal],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ExploreSpacing.x16,
            ExploreSpacing.x8,
            ExploreSpacing.x16,
            ExploreSpacing.x12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('explore.title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                  SavedScopeButton(
                    saved: saved,
                    savedCount: savedCount,
                    onChanged: onSavedChanged,
                  ),
                  const SizedBox(width: 8),
                  const NotificationBell(color: Colors.white),
                ],
              ),
              const SizedBox(height: ExploreSpacing.x8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: onQueryChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: context.tr('p03_search_hint'),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: onClearQuery,
                              ),
                        filled: true,
                        fillColor: AppColors.surface,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.ocean,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterButton(
                    key: const ValueKey('explore.filterButton'),
                    activeCount: filterActiveCount,
                    onPressed: onFilterPressed,
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

/// `Daftar | Peta` as a Material 3 [SegmentedButton].
///
/// It lives in the results line that scrolls with the list, so the fixed header
/// stays short. Icons keep it recognisable; labels carry the meaning.
class ExploreViewSwitch extends StatelessWidget {
  const ExploreViewSwitch({
    super.key,
    required this.mapMode,
    required this.onChanged,
  });

  final bool mapMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      key: const ValueKey('explore.viewSwitch'),
      segments: [
        ButtonSegment<bool>(
          value: false,
          icon: const Icon(Icons.view_agenda_outlined, size: 14),
          label: Text(
            context.tr('explore.viewList'),
            key: const ValueKey('explore.view.list'),
          ),
        ),
        ButtonSegment<bool>(
          value: true,
          icon: const Icon(Icons.map_outlined, size: 14),
          label: Text(
            context.tr('explore.viewMap'),
            key: const ValueKey('explore.view.map'),
          ),
        ),
      ],
      selected: {mapMode},
      onSelectionChanged: (values) => onChanged(values.first),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: ExploreSpacing.x4),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        tapTargetSize: MaterialTapTargetSize.padded,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textSecondary,
        selectedBackgroundColor: AppColors.ocean,
        selectedForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        ),
      ),
    );
  }
}

/// Opens the filter sheet, badged with the number of active filter groups.
///
/// On the gradient header it is a white tile so it reads as an action next to
/// the search field, not as another filter value.
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.activeCount,
    required this.onPressed,
  });

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = activeCount > 0;
    final button = IconButton(
      tooltip: active
          ? context.tr('p03_filter_active', {'n': '$activeCount'})
          : context.tr('p03_filter_action'),
      icon: const Icon(Icons.tune),
      color: active ? Colors.white : AppColors.ocean,
      style: IconButton.styleFrom(
        backgroundColor: active ? AppColors.ocean : AppColors.surface,
        minimumSize: const Size.square(48),
        maximumSize: const Size.square(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: onPressed,
    );

    if (!active) return button;
    return Badge(
      key: const ValueKey('explore.filterCount'),
      backgroundColor: AppColors.coral,
      textColor: Colors.white,
      label: Text('$activeCount'),
      child: button,
    );
  }
}

/// Saved scope as a compact header action: bookmark + count.
///
/// At rest the button is transparent so it sits directly on the header
/// gradient, exactly like the notification bell. Only the active state fills
/// white: that fill is the toggle's state cue, not a second surface.
class SavedScopeButton extends StatelessWidget {
  const SavedScopeButton({
    super.key,
    required this.saved,
    required this.savedCount,
    required this.onChanged,
  });

  final bool saved;
  final int savedCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final foreground = saved ? AppColors.ocean : Colors.white;
    final background = saved ? AppColors.surface : Colors.transparent;

    return Semantics(
      button: true,
      toggled: saved,
      label: context.tr('p03_scope_saved'),
      child: Tooltip(
        message: context.tr('p03_scope_saved'),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const ValueKey('explore.scope.saved'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => onChanged(!saved),
            child: Container(
              height: 48,
              constraints: const BoxConstraints(minWidth: 48),
              padding: EdgeInsets.symmetric(
                horizontal: savedCount > 0 ? 10 : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    saved ? Icons.bookmark : Icons.bookmark_outline,
                    size: 20,
                    color: foreground,
                  ),
                  if (savedCount > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$savedCount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tokens for the filters that are narrowing the results, each labelled with
/// its dimension. This is the only place chips/tokens belong: they summarise
/// active state and can be removed — they never navigate or select a view.
class ActiveFilterBar extends StatelessWidget {
  const ActiveFilterBar({
    super.key,
    required this.selection,
    required this.onChanged,
    this.horizontalPadding = 16,
  });

  final ExploreFilterSelection selection;
  final ValueChanged<ExploreFilterSelection> onChanged;

  /// Horizontal inset. The Explore list already has its own padding, so it
  /// passes 0 to keep the tokens aligned with the cards.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final tokens = <Widget>[
      if (selection.category != 'semua')
        _FilterToken(
          key: const ValueKey('explore.activeFilter.category'),
          icon: CategoryIcons.iconFor(selection.category),
          label:
              '${context.tr('p03_filter_category')}: '
              '${context.tr('cat.${selection.category}')}',
          onRemove: () => onChanged(selection.copyWith(category: 'semua')),
        ),
      if (selection.distance != DistanceBand.semua)
        _FilterToken(
          key: const ValueKey('explore.activeFilter.distance'),
          icon: Icons.straighten,
          label:
              '${context.tr('p03_filter_distance')}: '
              '${context.tr('p03_distance_${selection.distance.name}')}',
          onRemove: () => onChanged(
            selection.copyWith(distance: DistanceBand.semua),
          ),
        ),
      if (selection.condition != null)
        _FilterToken(
          key: const ValueKey('explore.activeFilter.condition'),
          icon: Icons.health_and_safety_outlined,
          label:
              '${context.tr('p03_map_condition')}: '
              '${selection.condition!.label(context)}',
          onRemove: () => onChanged(selection.copyWith(clearCondition: true)),
        ),
    ];

    if (tokens.isEmpty) return const SizedBox.shrink();

    return Padding(
      key: const ValueKey('explore.activeFilters'),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        ExploreSpacing.x12,
        horizontalPadding,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: ExploreSpacing.x8,
              runSpacing: ExploreSpacing.x8,
              children: tokens,
            ),
          ),
          const SizedBox(width: ExploreSpacing.x4),
          TextButton(
            key: const ValueKey('explore.clearFilters'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ocean,
              padding: const EdgeInsets.symmetric(horizontal: ExploreSpacing.x8),
              minimumSize: const Size(0, 48),
            ),
            onPressed: () => onChanged(ExploreFilterSelection.none),
            child: Text(
              context.tr('p03_clear_all'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterToken extends StatelessWidget {
  const _FilterToken({
    super.key,
    required this.icon,
    required this.label,
    required this.onRemove,
  });

  final IconData icon;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: AppColors.ocean.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onRemove,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ExploreSpacing.x8,
            ExploreSpacing.x4,
            ExploreSpacing.x8,
            ExploreSpacing.x4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.ocean),
              const SizedBox(width: ExploreSpacing.x8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: ExploreSpacing.x4),
              const Icon(
                Icons.close,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim result line above the list. It scrolls with the list so the fixed
/// header never eats the viewport.
///
/// The line owns the view switch: `Daftar | Peta` sits next to the count it
/// controls, so the user never has to look back up at the header. The count is
/// plain text — it is information, not a control. In map mode the rail is
/// hidden, so [categoryId] adds a compact chip that opens the category picker.
class ExploreResultsBar extends StatelessWidget {
  const ExploreResultsBar({
    super.key,
    required this.count,
    required this.mapMode,
    required this.onViewChanged,
    this.categoryId,
    this.onCategoryPressed,
    this.loading = false,
  });

  final int count;
  final bool mapMode;
  final ValueChanged<bool> onViewChanged;
  final String? categoryId;
  final VoidCallback? onCategoryPressed;

  /// While the first page loads the count is unknown; a skeleton keeps the
  /// line's height so nothing jumps when the number arrives.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final showCategory =
        mapMode && categoryId != null && onCategoryPressed != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ExploreSpacing.x16,
        ExploreSpacing.x8,
        ExploreSpacing.x16,
        ExploreSpacing.x8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                // The map itself shows its project count, so the bar leaves
                // that space to the category control there.
                if (!showCategory)
                  Flexible(
                    child: loading
                        ? const Skeleton(
                            key: ValueKey('explore.resultsCount'),
                            width: 88,
                            height: 18,
                            radius: 4,
                          )
                        : Text(
                            '${context.tr('explore.projects')} · $count',
                            key: const ValueKey('explore.resultsCount'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ocean,
                            ),
                          ),
                  ),
                if (showCategory) ...[
                  const SizedBox(width: ExploreSpacing.x8),
                  // The chip gets the whole leftover width instead of sharing
                  // it with the spacer, so its label is not ellipsized on a
                  // phone even when the view switch is beside it.
                  Flexible(
                    child: _MapCategoryChip(
                      categoryId: categoryId!,
                      onPressed: onCategoryPressed!,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: ExploreSpacing.x8),
          ExploreViewSwitch(mapMode: mapMode, onChanged: onViewChanged),
        ],
      ),
    );
  }
}

class _MapCategoryChip extends StatelessWidget {
  const _MapCategoryChip({required this.categoryId, required this.onPressed});

  final String categoryId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final all = categoryId == 'semua';
    final label = all
        ? context.tr('p03_category_label')
        : context.tr('cat.$categoryId');

    return Tooltip(
      message: context.tr('p03_category_label'),
      child: ActionChip(
        key: const ValueKey('explore.mapCategoryChip'),
        avatar: Icon(
          all ? Icons.grid_view_rounded : CategoryIcons.iconFor(categoryId),
          size: 16,
          color: AppColors.ocean,
        ),
        label: Text(label),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.ocean,
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
        onPressed: onPressed,
      ),
    );
  }
}
