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
  isScrollControlled: true,
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
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
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: categoryIds.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
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
              ),
            ],
          ),
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
    final label = context.tr('cat.$categoryId');
    final color = CategoryIcons.colorFor(categoryId);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? AppColors.ocean.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.ocean : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: ExcludeSemantics(
                    child: CategoryIcon(
                      category: categoryId,
                      size: 32,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? AppColors.ocean : AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 20,
                  color: selected ? AppColors.ocean : AppColors.inactiveTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
