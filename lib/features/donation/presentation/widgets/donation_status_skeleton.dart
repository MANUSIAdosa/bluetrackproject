import 'package:flutter/material.dart';

import '../../../../shared/widgets/skeleton.dart';

/// Content-shaped skeleton shown while the result status is loading.
class DonationStatusSkeleton extends StatelessWidget {
  const DonationStatusSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Skeleton(width: 96, height: 96, radius: 48),
        SizedBox(height: 20),
        Skeleton(width: 200, height: 24),
        SizedBox(height: 10),
        Skeleton(width: 260, height: 14),
        SizedBox(height: 24),
        Skeleton(height: 168, radius: 16),
        SizedBox(height: 20),
        Skeleton(height: 52, radius: 12),
        SizedBox(height: 12),
        Skeleton(height: 52, radius: 12),
      ],
    );
  }
}
