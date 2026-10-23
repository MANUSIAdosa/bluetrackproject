import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';

/// Icon + colour per sea category, so every surface that stands in for a
/// category (map markers, filter sheet, legend) shows the same glyph.
///
/// The colours come from [AppColors] — the palette is fixed, not per-widget.
abstract final class CategoryIcons {
  /// The five categories of `assets/mock/filters.json`, in app order.
  static const List<String> categories = [
    'penyu',
    'karang',
    'mangrove',
    'mamalia_laut',
    'lamun',
  ];

  static const Map<String, IconData> _icons = {
    'penyu': Icons.pets,
    'karang': Icons.blur_on,
    'mangrove': Icons.forest,
    'mamalia_laut': Icons.set_meal,
    'lamun': Icons.grass,
  };

  static const Map<String, Color> _colors = {
    'penyu': AppColors.teal,
    'karang': AppColors.coral,
    'mangrove': AppColors.success,
    'mamalia_laut': AppColors.ocean,
    'lamun': AppColors.oceanDeep,
  };

  /// Generic sea icon for an unknown category, so callers never crash on data
  /// that is newer than the app.
  static IconData iconFor(String category) =>
      _icons[category] ?? Icons.waves;

  static Color colorFor(String category) =>
      _colors[category] ?? AppColors.ocean;
}

/// Category glyph with the localized category name attached for screen
/// readers. Unknown categories render the generic sea icon.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.category,
    this.size = 20,
    this.color,
  });

  final String category;
  final double size;

  /// Overrides the category colour (map markers draw the icon on a coloured
  /// pin and keep the glyph white).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final label = context.tr('cat.$category');
    return Semantics(
      label: label,
      child: Icon(
        CategoryIcons.iconFor(category),
        size: size,
        color: color ?? CategoryIcons.colorFor(category),
      ),
    );
  }
}
