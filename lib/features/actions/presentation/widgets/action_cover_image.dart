import 'package:flutter/material.dart';

/// Cover image for an action, with a themed fallback when the asset is
/// missing or cannot load.
class ActionCoverImage extends StatelessWidget {
  const ActionCoverImage({
    super.key,
    required this.imageAsset,
    this.iconSize = 28,
  });

  final String imageAsset;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.primary, colors.secondary]),
      ),
      child: Center(
        child: Icon(
          Icons.eco_outlined,
          size: iconSize,
          color: colors.onPrimary,
        ),
      ),
    );

    if (imageAsset.isEmpty) return fallback;

    return Image.asset(
      imageAsset,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
