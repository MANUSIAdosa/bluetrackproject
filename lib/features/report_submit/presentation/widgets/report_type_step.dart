import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../project/domain/report.dart';

/// Step 3 of "Lapor Temuan": choose the finding type and its severity.
///
/// Both choices are single-select and stored in the wizard draft by the page.
/// Selection is never signalled by colour alone: selected cards and severity
/// chips also show a filled check, and every option keeps its text label.
class ReportTypeStep extends StatelessWidget {
  const ReportTypeStep({
    super.key,
    required this.category,
    required this.severity,
    required this.onCategoryChanged,
    required this.onSeverityChanged,
    this.showValidation = false,
  });

  /// Current choice, restored from the draft.
  final ReportCategory? category;
  final ReportSeverity? severity;

  final ValueChanged<ReportCategory> onCategoryChanged;
  final ValueChanged<ReportSeverity> onSeverityChanged;

  /// True after the user tried to continue without completing both choices.
  /// Errors disappear as soon as the missing choice is made.
  final bool showValidation;

  @override
  Widget build(BuildContext context) {
    final categoryMissing = showValidation && category == null;
    final severityMissing = showValidation && severity == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('report_type_title'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        for (final option in _categoryOptions) ...[
          _CategoryCard(
            category: option.category,
            icon: option.icon,
            selected: option.category == category,
            onTap: () => onCategoryChanged(option.category),
          ),
          const SizedBox(height: 10),
        ],
        if (categoryMissing)
          _InlineError(
            key: const ValueKey('report_type_category_error'),
            message: context.tr('report_type_category_error'),
          ),
        const SizedBox(height: 16),
        Text(
          context.tr('report_type_severity_title'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < ReportSeverity.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _SeverityOption(
                  severity: ReportSeverity.values[i],
                  selected: ReportSeverity.values[i] == severity,
                  onTap: () => onSeverityChanged(ReportSeverity.values[i]),
                ),
              ),
            ],
          ],
        ),
        if (severity case final value?)
          Padding(
            key: const ValueKey('report_type_severity_description'),
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _severityDescription(context, value),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (severityMissing)
          _InlineError(
            key: const ValueKey('report_type_severity_error'),
            message: context.tr('report_type_severity_error'),
          ),
      ],
    );
  }
}

/// Temporary Material glyphs for the five report categories.
///
/// TODO(lapor): `shared/widgets` has no report-category icon widget yet, and
/// P04 keeps its own mapping in `p04_report_visuals.dart`. Move both into one
/// shared widget once that refactor is approved; `shared/widgets` must not be
/// edited as part of this step.
const _categoryOptions = <_CategoryOption>[
  _CategoryOption(ReportCategory.marineDebris, Icons.delete_outline),
  _CategoryOption(ReportCategory.damagedReef, Icons.blur_on),
  _CategoryOption(ReportCategory.deforestedMangrove, Icons.forest),
  _CategoryOption(ReportCategory.destructiveFishing, Icons.set_meal_outlined),
  _CategoryOption(ReportCategory.affectedWildlife, Icons.pets),
];

class _CategoryOption {
  const _CategoryOption(this.category, this.icon);

  final ReportCategory category;
  final IconData icon;
}

String _categoryLabel(BuildContext context, ReportCategory category) =>
    context.tr(switch (category) {
      ReportCategory.marineDebris => 'report_type_category_marine_debris',
      ReportCategory.damagedReef => 'report_type_category_damaged_reef',
      ReportCategory.deforestedMangrove =>
        'report_type_category_deforested_mangrove',
      ReportCategory.destructiveFishing =>
        'report_type_category_destructive_fishing',
      ReportCategory.affectedWildlife =>
        'report_type_category_affected_wildlife',
    });

String _categoryDescription(BuildContext context, ReportCategory category) =>
    context.tr(switch (category) {
      ReportCategory.marineDebris => 'report_type_category_marine_debris_desc',
      ReportCategory.damagedReef => 'report_type_category_damaged_reef_desc',
      ReportCategory.deforestedMangrove =>
        'report_type_category_deforested_mangrove_desc',
      ReportCategory.destructiveFishing =>
        'report_type_category_destructive_fishing_desc',
      ReportCategory.affectedWildlife =>
        'report_type_category_affected_wildlife_desc',
    });

String _severityLabel(BuildContext context, ReportSeverity severity) =>
    context.tr(switch (severity) {
      ReportSeverity.low => 'report_type_severity_low',
      ReportSeverity.medium => 'report_type_severity_medium',
      ReportSeverity.high => 'report_type_severity_high',
    });

String _severityDescription(BuildContext context, ReportSeverity severity) =>
    context.tr(switch (severity) {
      ReportSeverity.low => 'report_type_severity_low_desc',
      ReportSeverity.medium => 'report_type_severity_medium_desc',
      ReportSeverity.high => 'report_type_severity_high_desc',
    });

IconData _severityIcon(ReportSeverity severity) => switch (severity) {
  ReportSeverity.low => Icons.eco_outlined,
  ReportSeverity.medium => Icons.warning_amber_rounded,
  ReportSeverity.high => Icons.report_problem_outlined,
};

Color _severityColor(ReportSeverity severity) => switch (severity) {
  ReportSeverity.low => AppColors.success,
  ReportSeverity.medium => AppColors.warning,
  ReportSeverity.high => AppColors.danger,
};

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final ReportCategory category;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppDimens.cardRadius));
    final label = _categoryLabel(context, category);
    final description = _categoryDescription(context, category);

    return Semantics(
      key: ValueKey('report_type_category_${category.id}'),
      button: true,
      selected: selected,
      label: label,
      hint: description,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.ocean : AppColors.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? AppColors.oceanDeep : AppColors.border,
                width: selected ? 2 : 1,
              ),
              // The gradient only appears on the selected card, so it works as
              // a second, colour-independent cue next to the filled check.
              gradient: selected
                  ? const LinearGradient(
                      colors: [AppColors.ocean, AppColors.teal],
                    )
                  : null,
              color: selected ? null : AppColors.surface,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: selected ? Colors.white : AppColors.ocean,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.86)
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: selected ? 22 : 18,
                      color: selected ? Colors.white : AppColors.inactiveTab,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeverityOption extends StatelessWidget {
  const _SeverityOption({
    required this.severity,
    required this.selected,
    required this.onTap,
  });

  final ReportSeverity severity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(14));
    final label = _severityLabel(context, severity);

    return Semantics(
      key: ValueKey('report_type_severity_${severity.id}'),
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.ocean : AppColors.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? AppColors.oceanDeep : AppColors.border,
                width: selected ? 2 : 1,
              ),
              gradient: selected
                  ? const LinearGradient(
                      colors: [AppColors.ocean, AppColors.teal],
                    )
                  : null,
              color: selected ? null : AppColors.surface,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? Icons.check_circle : _severityIcon(severity),
                      size: selected ? 18 : 18,
                      color: selected ? Colors.white : _severityColor(severity),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
