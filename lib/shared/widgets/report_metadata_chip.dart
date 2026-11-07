import 'package:flutter/material.dart';

/// Shared status, severity and category chip for report surfaces.
class ReportMetadataChip extends StatelessWidget {
  const ReportMetadataChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.foregroundColor,
    this.filled = true,
    this.backgroundOpacity = 0.1,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.iconSize = 14,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w700,
    this.maxLabelLines,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
  });

  final IconData icon;
  final String label;
  final Color color;

  /// Colour of the icon and label. Defaults to [color]; pass a darker shade
  /// when [color] is too light to read as text on its own tint.
  final Color? foregroundColor;
  final bool filled;
  final double backgroundOpacity;
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final double fontSize;
  final FontWeight fontWeight;
  final int? maxLabelLines;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    final contentColor = foregroundColor ?? color;

    return Container(
      padding: padding,
      decoration: filled
          ? BoxDecoration(
              color: color.withValues(alpha: backgroundOpacity),
              borderRadius: borderRadius,
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: contentColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: maxLabelLines,
              overflow: maxLabelLines == null
                  ? TextOverflow.clip
                  : TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: contentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
