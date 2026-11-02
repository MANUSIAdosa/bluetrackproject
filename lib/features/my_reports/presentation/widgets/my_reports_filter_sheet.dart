import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../project/domain/report.dart';
import '../../../project/presentation/p04_report_visuals.dart';

/// Opens the status filter for My Reports and returns the chosen option id.
///
/// `all` clears the filter; every other value is a [ReportStatus.id]. The sheet
/// also shows how many reports sit behind each option, so a status that would
/// empty the list is visible before it is tapped.
Future<String?> showMyReportsFilterSheet(
  BuildContext context, {
  required String selectedId,
  required Map<String, int> counts,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.cardRadius),
      ),
    ),
    builder: (sheetContext) => _MyReportsFilterSheet(
      selectedId: selectedId,
      counts: counts,
    ),
  );
}

class _MyReportsFilterSheet extends StatelessWidget {
  const _MyReportsFilterSheet({
    required this.selectedId,
    required this.counts,
  });

  final String selectedId;
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final options = <_FilterOption>[
      _FilterOption(
        id: 'all',
        label: context.tr('my_reports.filter_all'),
        icon: Icons.apps_outlined,
        color: AppColors.ocean,
      ),
      for (final status in ReportStatus.values)
        _FilterOption(
          id: status.id,
          label: context.p04StatusLabel(status),
          icon: context.p04StatusIcon(status),
          color: context.p04StatusColor(status),
        ),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.padding,
          0,
          AppDimens.padding,
          AppDimens.padding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('my_reports.filter_title'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('my-reports-filter-close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: context.tr('p04_detail_close'),
                  icon: const Icon(Icons.close),
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final option in options) ...[
              _FilterOptionTile(
                option: option,
                count: counts[option.id] ?? 0,
                selected: option.id == selectedId,
                onTap: () => Navigator.of(context).pop(option.id),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

class _FilterOptionTile extends StatelessWidget {
  const _FilterOptionTile({
    required this.option,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _FilterOption option;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(12);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? option.color.withValues(alpha: 0.08)
            : AppColors.background,
        borderRadius: borderRadius,
        child: InkWell(
          key: ValueKey('my-reports-filter-option-${option.id}'),
          borderRadius: borderRadius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: selected
                    ? option.color.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: option.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(option.icon, size: 18, color: option.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                if (selected)
                  Icon(Icons.check_circle, size: 20, color: option.color)
                else
                  const SizedBox(width: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
