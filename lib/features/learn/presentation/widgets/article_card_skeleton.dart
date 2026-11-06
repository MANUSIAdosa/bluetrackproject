import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/skeleton.dart';

/// Loading placeholder matching the P16 article card layout.
class ArticleCardSkeleton extends StatelessWidget {
  const ArticleCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Skeleton(radius: 12),
          ),
          SizedBox(height: 8),
          Skeleton(width: 220, height: 16),
          SizedBox(height: 8),
          Skeleton(height: 14),
          SizedBox(height: 6),
          Skeleton(width: 180, height: 14),
          SizedBox(height: 8),
          Skeleton(width: 140, height: 12),
        ],
      ),
    );
  }
}
