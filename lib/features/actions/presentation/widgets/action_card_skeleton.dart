import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/skeleton.dart';

/// Loading placeholder shaped like the compact two-column [ActionCard].
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
            aspectRatio: 4 / 3,
            child: Skeleton(radius: 0),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(height: 14),
                SizedBox(height: 4),
                FractionallySizedBox(
                  widthFactor: 0.62,
                  alignment: Alignment.centerLeft,
                  child: Skeleton(height: 14),
                ),
                SizedBox(height: 7),
                Skeleton(height: 10),
                SizedBox(height: 4),
                Skeleton(height: 10),
                SizedBox(height: 4),
                Skeleton(height: 10),
                SizedBox(height: 4),
                FractionallySizedBox(
                  widthFactor: 0.72,
                  alignment: Alignment.centerLeft,
                  child: Skeleton(height: 10),
                ),
                SizedBox(height: 8),
                Skeleton(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
