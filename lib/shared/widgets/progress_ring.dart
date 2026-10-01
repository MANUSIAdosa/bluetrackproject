import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Circular funding progress (Explore project cards).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 44,
    this.label,
  });

  /// 0.0 – 1.0; clamped internally.
  final double value;
  final double size;

  /// Optional center text (e.g. "75%"); defaults to the rounded percentage.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: clamped,
              strokeWidth: 4,
              backgroundColor: AppColors.border,
              color: AppColors.ocean,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            label ?? '${(clamped * 100).round()}%',
            style: TextStyle(
              fontSize: size * 0.24,
              fontWeight: FontWeight.w700,
              color: AppColors.ocean,
            ),
          ),
        ],
      ),
    );
  }
}
