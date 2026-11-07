import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';

/// Icon + colour per sea category, so every surface that stands in for a
/// category (map markers, filter sheet, legend) shows the same glyph.
///
/// Category artwork lives in `assets/icons/categories/<id>.png`; a page never
/// points at a file itself, it renders [CategoryIcon]. The Material glyph is
/// the fallback while a file is missing.
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
    'semua': Icons.grid_view_rounded,
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

  /// Artwork for categories that have a bundled PNG; other ids use the glyph.
  static String? assetFor(String category) => categories.contains(category)
      ? 'assets/icons/categories/$category.png'
      : null;

  /// Generic sea icon for an unknown category, so callers never crash on data
  /// that is newer than the app.
  static IconData iconFor(String category) => _icons[category] ?? Icons.waves;

  static Color colorFor(String category) =>
      _colors[category] ?? AppColors.ocean;
}

/// Category artwork with the localized category name attached for screen
/// readers. Until the PNG has a frame — and whenever the file is missing — the
/// widget stays on a neutral tinted disc, so no Material glyph flashes first.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    super.key,
    required this.category,
    this.size = 20,
    this.color,
  });

  final String category;
  final double size;

  /// Tints the fallback glyph (map markers draw it white on a coloured pin).
  /// Category artwork renders with its own colours.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final label = context.tr('cat.$category');
    final fallback = Icon(
      CategoryIcons.iconFor(category),
      size: size,
      color: color ?? CategoryIcons.colorFor(category),
    );
    // Neutral disc at the artwork's footprint; only the missing-file state
    // falls back to the Material glyph.
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: CategoryIcons.colorFor(category).withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(dimension: size),
    );
    final asset = CategoryIcons.assetFor(category);
    if (asset == null) {
      return Semantics(label: label, child: fallback);
    }

    // Artwork is 434 px wide but a badge/marker shows it at 20–48 dp; decode
    // at the physical size the screen actually paints.
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Semantics(
      label: label,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: pixels,
        cacheHeight: pixels,
        // The artwork keeps its own colours; [color] only tints the fallback.
        frameBuilder: (_, child, frame, _) =>
            frame == null ? placeholder : child,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
