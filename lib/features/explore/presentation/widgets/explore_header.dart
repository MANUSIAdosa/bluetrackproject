import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/category_icon.dart';
import '../../../../shared/widgets/notification_bell.dart';
import '../../domain/explore_map_data.dart';
import 'condition_label.dart';
import 'filter_sheet.dart';

/// Compact gradient header of Jelajahi: identity, search, filter and the
/// list/map action.
///
/// The header is intentionally short: search, filter and the view toggle are
/// primary actions and stay reachable, while the category rail and active
/// filter tokens live in the scrollable list so they never eat the viewport.
class ExploreHeader extends StatelessWidget {
  const ExploreHeader({
    super.key,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.filterActiveCount,
    required this.onFilterPressed,
    required this.mapMode,
    required this.onViewChanged,
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final int filterActiveCount;
  final VoidCallback onFilterPressed;
  final bool mapMode;
  final ValueChanged<bool> onViewChanged;

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
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
                  _ViewModeButton(
                    mapMode: mapMode,
                    onChanged: onViewChanged,
                  ),
                  const SizedBox(width: 2),
                  const NotificationBell(color: Colors.white),
                ],
              ),
              const SizedBox(height: 10),
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

/// One action that switches to the other view. Showing the destination (map
/// when in list mode, list when on the map) keeps the header to a single
/// button instead of a second segmented control.
class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({required this.mapMode, required this.onChanged});

  final bool mapMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final nextMap = !mapMode;

    return IconButton(
      key: ValueKey(nextMap ? 'explore.view.map' : 'explore.view.list'),
      tooltip: context.tr(nextMap ? 'explore.viewMap' : 'explore.viewList'),
      icon: Icon(
        nextMap ? Icons.map_outlined : Icons.view_agenda_outlined,
        color: Colors.white,
      ),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        minimumSize: const Size.square(44),
        maximumSize: const Size.square(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: () => onChanged(nextMap),
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

/// Jelajahi / Tersimpan — two contexts, not two filters.
///
/// The saved collection is a personal scope, so it gets its own switch instead
/// of sharing the category row or the filter sheet.
class ExploreScopeSwitch extends StatelessWidget {
  const ExploreScopeSwitch({
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
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ScopeTab(
              key: const ValueKey('explore.scope.explore'),
              icon: Icons.explore_outlined,
              label: context.tr('p03_scope_explore'),
              selected: !saved,
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ScopeTab(
              key: const ValueKey('explore.scope.saved'),
              icon: Icons.bookmark_outline,
              label: context.tr('p03_scope_saved'),
              count: savedCount,
              selected: saved,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeTab extends StatelessWidget {
  const _ScopeTab({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.ocean : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ),
                  if (count != null && count! > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.22)
                            : AppColors.ocean.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : AppColors.ocean,
                        ),
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

/// Single-select category rail. Icons instead of chips: category is the only
/// dimension here, and the coloured glyph makes the five categories scannable.
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categoryIds,
    required this.selectedId,
    required this.onSelected,
    this.horizontalPadding = 16,
  });

  final List<String> categoryIds;
  final String selectedId;
  final ValueChanged<String> onSelected;

  /// Horizontal inset. The Explore list already has its own padding, so it
  /// passes 0 to keep the rail aligned with the cards.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            10,
            horizontalPadding,
            6,
          ),
          child: Text(
            context.tr('p03_category_label'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: categoryIds.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final id = categoryIds[index];
              return _CategoryOption(
                key: ValueKey('explore.category.$id'),
                categoryId: id,
                selected: id == selectedId,
                onTap: () => onSelected(id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    super.key,
    required this.categoryId,
    required this.selected,
    required this.onTap,
  });

  final String categoryId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final all = categoryId == 'semua';
    final color = all ? AppColors.ocean : CategoryIcons.colorFor(categoryId);
    final icon = all
        ? Icons.grid_view_rounded
        : CategoryIcons.iconFor(categoryId);
    final label = context.tr('cat.$categoryId');

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? color : color.withValues(alpha: 0.10),
                  border: Border.all(
                    color: selected
                        ? color
                        : color.withValues(alpha: 0.20),
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
            ],
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
      padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 8, children: tokens),
          ),
          const SizedBox(width: 4),
          TextButton(
            key: const ValueKey('explore.clearFilters'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ocean,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
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
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.ocean),
              const SizedBox(width: 6),
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
              const SizedBox(width: 4),
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

/// Slim result count above the list. It stays fixed so the effect of a filter
/// is visible while scrolling; the view toggle lives in the header.
class ExploreResultsBar extends StatelessWidget {
  const ExploreResultsBar({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Text(
        '${context.tr('explore.projects')} · $count',
        key: const ValueKey('explore.resultsCount'),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
