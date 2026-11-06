import 'dart:math' as math;

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
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
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

/// Compact two-segment control that shows both views and which one is active.
///
/// The results line owns it: the switch sits next to the count it affects.
/// Icons keep the bar slim; tooltips and semantics carry the labels.
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
    return Container(
      height: 54,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewSegment(
            key: const ValueKey('explore.view.list'),
            icon: Icons.view_agenda_outlined,
            label: context.tr('explore.viewList'),
            selected: !mapMode,
            onTap: () => onChanged(false),
          ),
          _ViewSegment(
            key: const ValueKey('explore.view.map'),
            icon: Icons.map_outlined,
            label: context.tr('explore.viewMap'),
            selected: mapMode,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ViewSegment extends StatelessWidget {
  const _ViewSegment({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? AppColors.ocean : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(child: Icon(icon, size: 20, color: foreground)),
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

  /// Horizontal inset, so the rail lines up with the content next to it.
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    // Labels wrap to two lines ("Marine mammals" in English), so reserve two
    // label lines. The rail keeps its 80dp design height at normal sizes and
    // grows with the accessibility text scale instead of clipping.
    final labelLine = MediaQuery.textScalerOf(context).scale(11 * 1.2) * 2;
    final railHeight = math.max(80.0, 48 + 5 + labelLine + 2);
    // The slot must fit the longest single word, otherwise a two-line label
    // like "Marine mammals" still ellipsizes. Measure with the bold weight,
    // which is the widest state, at the current text scale.
    var itemWidth = 72.0;
    for (final id in categoryIds) {
      for (final word in context.tr('cat.$id').split(' ')) {
        final painter = TextPainter(
          text: TextSpan(
            text: word,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        itemWidth = math.max(itemWidth, painter.width + 4);
        painter.dispose();
      }
    }

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
          height: railHeight,
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
                width: itemWidth,
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
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final String categoryId;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = CategoryIcons.colorFor(categoryId);
    final label = context.tr('cat.$categoryId');

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: width,
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
                    color: selected ? color : color.withValues(alpha: 0.20),
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
                child: ExcludeSemantics(
                  child: CategoryIcon(
                    category: categoryId,
                    // Artwork fills the 48dp ring; "Semua" keeps the smaller
                    // glyph it had before there was any artwork.
                    size: categoryId == 'semua' ? 22 : 42,
                    color: selected ? Colors.white : color,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      if (selection.distance != DistanceBand.semua)
        _FilterToken(
          key: const ValueKey('explore.activeFilter.distance'),
          icon: Icons.straighten,
          label:
              '${context.tr('p03_filter_distance')}: '
              '${context.tr('p03_distance_${selection.distance.name}')}',
          onRemove: () =>
              onChanged(selection.copyWith(distance: DistanceBand.semua)),
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
              padding: const EdgeInsets.symmetric(
                horizontal: ExploreSpacing.x8,
              ),
              minimumSize: const Size(0, 48),
            ),
            // Clearing the sheet filters must not undo the category the user
            // picked on the rail.
            onPressed: () => onChanged(selection.withoutRefinements),
            child: Text(
              context.tr('p03_clear_all'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
              const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
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
                            count == 1
                                ? context.tr('explore.projectCountOne')
                                : context.tr('explore.projectCount', {
                                    'n': '$count',
                                  }),
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
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          key: const ValueKey('explore.mapCategoryChip'),
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The artwork shows the current value; the arrow marks the
                  // chip as a picker, not a passive label.
                  ExcludeSemantics(
                    child: CategoryIcon(category: categoryId, size: 20),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ocean,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: AppColors.ocean,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
