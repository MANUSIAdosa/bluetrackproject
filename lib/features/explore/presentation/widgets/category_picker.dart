import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/category_icon.dart';

/// Compact category picker for map mode, where the rail is hidden.
///
/// The list keeps the visual rail; the map needs the same single choice in a
/// smaller surface, so this sheet is opened from the result bar's chip.
Future<String?> showCategoryPickerSheet(
  BuildContext context, {
  required List<String> categoryIds,
  required String selectedId,
}) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  backgroundColor: AppColors.surface,
  builder: (_) =>
      _CategoryPicker(categoryIds: categoryIds, selectedId: selectedId),
);

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.categoryIds, required this.selectedId});

  final List<String> categoryIds;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        key: const ValueKey('explore.categoryPicker'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('p03_category_label'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categoryIds.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.45,
              ),
              itemBuilder: (context, index) {
                final id = categoryIds[index];
                return _CategoryTile(
                  key: ValueKey('explore.categoryPicker.$id'),
                  categoryId: id,
                  selected: id == selectedId,
                  onTap: () => Navigator.of(context).pop(id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
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
    final label = context.tr('cat.$categoryId');

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? AppColors.ocean.withValues(alpha: 0.10)
            : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? AppColors.ocean : AppColors.border,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                all
                    ? const Icon(
                        Icons.grid_view_rounded,
                        size: 22,
                        color: AppColors.ocean,
                      )
                    : CategoryIcon(category: categoryId, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.ocean : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
