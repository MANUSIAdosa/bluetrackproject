import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/donation.dart';

/// Animated status icon, title, and one-line explanation for the result screen.
class DonationStatusHeader extends StatelessWidget {
  const DonationStatusHeader({
    super.key,
    required this.status,
    required this.title,
    required this.body,
    required this.semanticsLabel,
  });

  final DonationStatus status;
  final String title;
  final String body;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      DonationStatus.success => (AppColors.success, Icons.check_rounded),
      DonationStatus.failed => (AppColors.danger, Icons.close_rounded),
      DonationStatus.pending => (AppColors.warning, Icons.schedule_rounded),
    };

    return Column(
      children: [
        Semantics(
          label: semanticsLabel,
          image: true,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
