import 'package:flutter/material.dart';

/// Shared status, severity and category chip for report surfaces.
class ReportMetadataChip extends StatelessWidget {
  const ReportMetadataChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.filled = true,
    this.backgroundOpacity = 0.1,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.iconSize = 14,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w700,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final double backgroundOpacity;
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final double fontSize;
  final FontWeight fontWeight;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
