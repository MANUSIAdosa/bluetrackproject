import 'package:flutter/widgets.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/explore_map_data.dart';

/// Localized condition name ("Baik", "Perlu pemantauan", "Kritis"), shared by
/// the filter sheet and the map's project sheet so both read the same words.
extension ProjectConditionLabel on ProjectCondition {
  String label(BuildContext context) => context.tr('p03_condition_$id');
}
