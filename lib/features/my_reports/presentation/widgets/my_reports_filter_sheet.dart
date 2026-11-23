import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../project/domain/report.dart';
import '../../../project/presentation/p04_format.dart';
import '../../../project/presentation/p04_report_visuals.dart';

/// Opens the report-status list and returns the selected option id.
Future<String?> showMyReportsFilterSheet(
  BuildContext context, {
  required String selectedId,
  required Map<String, int> counts,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.68,
    ),
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.cardRadius),
      ),
    ),
    builder: (context) => _MyReportsFilterSheet(
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
    final languageCode = Localizations.localeOf(context).languageCode;
    final options = <_FilterOption>[
      _FilterOption(
        id: 'all',
        label: context.tr('my_reports.filter_all'),
        icon: Icons.grid_view_rounded,
        color: AppColors.ocean,
      ),
      for (final status in ReportStatus.values)
        _FilterOption(
          id: status.id,
          label: context.p04StatusLabel(status),
          icon: context.p04StatusIcon(status),
          color: context.p04StatusColor(status),
          iconColor: context.p04StatusForeground(status),
        ),
    ];

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.padding,
              0,
              4,
              4,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.ocean.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tune,
                    color: AppColors.ocean,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('my_reports.filter_title'),
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('my_reports.filter_hint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('my-reports-filter-close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: context.tr('p04_detail_close'),
                  icon: const Icon(Icons.close),
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.loose,
            child: ListView.separated(
              key: const ValueKey('my-reports-filter-list'),
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final option = options[index];
                return _FilterOptionTile(
                  option: option,
                  count: counts[option.id] ?? 0,
                  languageCode: languageCode,
                  selected: option.id == selectedId,
                  onTap: () => Navigator.of(context).pop(option.id),
                );
              },
            ),
          ),
        ],
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
    this.iconColor,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;

  /// Icon colour when [color] is too light to read as an icon on its tint.
  final Color? iconColor;
}

class _FilterOptionTile extends StatelessWidget {
  const _FilterOptionTile({
    required this.option,
    required this.count,
    required this.languageCode,
    required this.selected,
    required this.onTap,
  });

  final _FilterOption option;
  final int count;
  final String languageCode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final countLabel = P04Format.integer(count, languageCode);
    final semanticsLabel = context.tr('my_reports.filter_count', {
      'label': option.label,
      'count': countLabel,
    });

    return Semantics(
      key: ValueKey('my-reports-filter-option-${option.id}'),
      selected: selected,
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? AppColors.ocean.withValues(alpha: 0.08)
              : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? AppColors.ocean.withValues(alpha: 0.4)
                      : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: option.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      option.icon,
                      size: 20,
                      color: option.iconColor ?? option.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    countLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 20,
                    color: selected ? AppColors.ocean : AppColors.border,
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
