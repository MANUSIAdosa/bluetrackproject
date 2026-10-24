import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/report.dart';

/// Localized labels and shared visual identity for report enums.
///
/// The list, the chart and the detail sheet all use these helpers so a
/// category, severity or status never gets two different colours or icons.
extension P04ReportVisuals on BuildContext {
  /// Category label shown in list rows and the detail sheet.
  String p04CategoryLabel(ReportCategory category) => tr(switch (category) {
    ReportCategory.marineDebris => 'p04_category_marine_debris',
    ReportCategory.damagedReef => 'p04_category_damaged_reef',
    ReportCategory.deforestedMangrove => 'p04_category_deforested_mangrove',
    ReportCategory.destructiveFishing => 'p04_category_destructive_fishing',
    ReportCategory.affectedWildlife => 'p04_category_affected_wildlife',
  });

  /// Category glyph, reused by the list icon and the detail header.
  IconData p04CategoryIcon(ReportCategory category) => switch (category) {
    ReportCategory.marineDebris => Icons.delete_outline,
    ReportCategory.damagedReef => Icons.blur_on,
    ReportCategory.deforestedMangrove => Icons.forest,
    ReportCategory.destructiveFishing => Icons.set_meal_outlined,
    ReportCategory.affectedWildlife => Icons.pets,
  };

  /// Category accent colour from the fixed palette.
  Color p04CategoryColor(ReportCategory category) => switch (category) {
    ReportCategory.marineDebris => AppColors.ocean,
    ReportCategory.damagedReef => AppColors.coral,
    ReportCategory.deforestedMangrove => AppColors.success,
    ReportCategory.destructiveFishing => AppColors.danger,
    ReportCategory.affectedWildlife => AppColors.teal,
  };

  /// Severity label, which is also the chart y-axis label.
  String p04SeverityLabel(ReportSeverity severity) => tr(switch (severity) {
    ReportSeverity.low => 'p04_severity_low',
    ReportSeverity.medium => 'p04_severity_medium',
    ReportSeverity.high => 'p04_severity_high',
  });

  /// Severity accent colour.
  Color p04SeverityColor(ReportSeverity severity) => switch (severity) {
    ReportSeverity.low => AppColors.success,
    ReportSeverity.medium => AppColors.warning,
    ReportSeverity.high => AppColors.danger,
  };

  /// Workflow status label.
  String p04StatusLabel(ReportStatus status) => tr(switch (status) {
    ReportStatus.submitted => 'p04_status_submitted',
    ReportStatus.verified => 'p04_status_verified',
    ReportStatus.followedUp => 'p04_status_followed_up',
    ReportStatus.completed => 'p04_status_completed',
  });

  /// Status glyph. Icon plus text keeps the chip understandable without colour.
  IconData p04StatusIcon(ReportStatus status) => switch (status) {
    ReportStatus.submitted => Icons.schedule_outlined,
    ReportStatus.verified => Icons.verified_outlined,
    ReportStatus.followedUp => Icons.autorenew,
    ReportStatus.completed => Icons.check_circle_outline,
  };

  /// Status accent colour.
  Color p04StatusColor(ReportStatus status) => switch (status) {
    ReportStatus.submitted => AppColors.inactiveTab,
    ReportStatus.verified => AppColors.teal,
    ReportStatus.followedUp => AppColors.ocean,
    ReportStatus.completed => AppColors.success,
  };
}
