import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Determinate horizontal progress bar (funding progress).
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.height = 8});

  /// 0.0 – 1.0; clamped internally.
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: AppColors.border),
            FractionallySizedBox(
              widthFactor: clamped,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.ocean, AppColors.teal],
                  ),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
