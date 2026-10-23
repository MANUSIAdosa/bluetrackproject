import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/project_card.dart';
import '../../domain/project.dart';

/// Section heading used by the Jelajahi list ("Untuk minatmu", "Proyek").
Widget exploreSectionHeader(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Text(
    text,
    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
  ),
);

/// Horizontal "Untuk minatmu" rail.
///
/// Its height is measured from the cards themselves ([IntrinsicHeight]) rather
/// than pinned to a constant, so it can never be shorter than a card: a
/// one-line or two-line title, a longer location or a large text scale are all
/// fine. Cards are compact — no donate CTA — and stretched to one height.
class ForYouRail extends StatelessWidget {
  const ForYouRail({
    super.key,
    required this.projects,
    required this.onSavedChanged,
  });

  final List<Project> projects;
  final VoidCallback onSavedChanged;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < projects.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: ProjectCard(
                  project: projects[i],
                  showDonateButton: false,
                  onSavedChanged: onSavedChanged,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Daftar/Peta segmented button. The two modes are views of the same filtered
/// result set, so switching never resets a filter.
class ListMapToggle extends StatelessWidget {
  const ListMapToggle({
    super.key,
    required this.mapMode,
    required this.onChanged,
  });

  final bool mapMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // The toggle is narrower than the row, and the surrounding Column centres
      // its children: without this it would drift away from the search field
      // and the chips, which both start on the base padding.
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(context.tr('explore.viewList')),
              icon: const Icon(Icons.view_list_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text(context.tr('explore.viewMap')),
              icon: const Icon(Icons.map_outlined),
            ),
          ],
          selected: {mapMode},
          onSelectionChanged: (set) => onChanged(set.first),
          showSelectedIcon: false,
        ),
      ),
    );
  }
}

/// Opens the filter sheet, badged with the number of active filter groups.
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
    final button = IconButton(
      tooltip: activeCount > 0
          ? context.tr('p03_filter_active', {'n': '$activeCount'})
          : context.tr('p03_filter_action'),
      icon: const Icon(Icons.tune),
      color: activeCount > 0 ? AppColors.ocean : AppColors.textSecondary,
      style: IconButton.styleFrom(minimumSize: const Size.square(48)),
      onPressed: onPressed,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: activeCount > 0
            ? AppColors.ocean.withValues(alpha: 0.10)
            : Colors.transparent,
        border: Border.all(
          color: activeCount > 0 ? AppColors.ocean : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: activeCount > 0
          ? Badge(
              key: const ValueKey('explore.filterCount'),
              label: Text('$activeCount'),
              child: button,
            )
          : button,
    );
  }
}

/// Bookmark toggle for the saved-projects collection, beside the search field.
///
/// The collection is a context of its own, so it is a button and not a chip in
/// the category row. While it is on, the chip row and the search field keep
/// narrowing *within* the saved projects.
class SavedFilterButton extends StatelessWidget {
  const SavedFilterButton({
    super.key,
    required this.active,
    required this.savedCount,
    required this.onChanged,
  });

  final bool active;

  /// Number of saved projects, badged on the button when there is any.
  final int savedCount;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      // Names the action, so it reads correctly in either state.
      tooltip: context.tr(
        active ? 'explore.savedFilter.off' : 'explore.savedFilter.on',
      ),
      icon: Icon(active ? Icons.bookmark : Icons.bookmark_outline),
      color: active ? AppColors.ocean : AppColors.textSecondary,
      // Material's minimum touch target.
      style: IconButton.styleFrom(minimumSize: const Size.square(48)),
      onPressed: () => onChanged(!active),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? AppColors.ocean.withValues(alpha: 0.10)
            : Colors.transparent,
        border: Border.all(color: active ? AppColors.ocean : AppColors.border),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: savedCount > 0
          ? Badge(label: Text('$savedCount'), child: button)
          : button,
    );
  }
}
