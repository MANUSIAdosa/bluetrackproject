import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/skeleton.dart';

/// Loading placeholder shaped like the content-sized [ActionCard]: 16:9 cover,
/// a readable body block, and the action hint at the bottom.
class ActionCardSkeleton extends StatelessWidget {
  const ActionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: Skeleton(radius: 0),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(height: 16),
                SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: 0.7,
                  alignment: Alignment.centerLeft,
                  child: Skeleton(height: 16),
                ),
                SizedBox(height: 12),
                Skeleton(height: 11),
                SizedBox(height: 5),
                Skeleton(height: 11),
                SizedBox(height: 5),
                FractionallySizedBox(
                  widthFactor: 0.8,
                  alignment: Alignment.centerLeft,
                  child: Skeleton(height: 11),
                ),
                SizedBox(height: 5),
                FractionallySizedBox(
                  widthFactor: 0.6,
                  alignment: Alignment.centerLeft,
                  child: Skeleton(height: 11),
                ),
                SizedBox(height: 5),
                FractionallySizedBox(
                  widthFactor: 0.5,
                  alignment: Alignment.centerLeft,
                  child: Skeleton(height: 11),
                ),
                SizedBox(height: 12),
                FractionallySizedBox(
                  widthFactor: 0.45,
                  alignment: Alignment.centerLeft,
                  child: Skeleton(height: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
