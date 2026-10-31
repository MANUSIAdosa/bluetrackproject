import 'package:flutter/widgets.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/explore_map_data.dart';

/// Localized condition name ("Baik", "Perlu pemantauan", "Kritis"), shared by
/// the filter sheet and the map's project sheet so both read the same words.
extension ProjectConditionLabel on ProjectCondition {
  String label(BuildContext context) => context.tr('p03_condition_$id');
}

/// Status colour of a conservation area, used by the map polygons and by the
/// legend that explains them — one source, so the two can never disagree.
extension ProjectConditionColor on ProjectCondition {
  Color get color => switch (this) {
    ProjectCondition.baik => AppColors.success,
    ProjectCondition.pemantauan => AppColors.warning,
    ProjectCondition.kritis => AppColors.danger,
  };
}
