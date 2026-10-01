import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'primary_button.dart';

/// Shared login prompt card (P02/P06 and protected tabs).
///
/// Preserves the origin: after sign-in the user returns to [returnLocation].
class LoginPromptCard extends StatelessWidget {
  const LoginPromptCard({
    super.key,
    required this.returnLocation,
    this.title,
    this.body,
  });

  final String returnLocation;
  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.ocean.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 28,
                color: AppColors.ocean,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title ?? context.tr('login.prompt.title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              body ?? context.tr('login.prompt.body'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: context.tr('login.prompt.button'),
              onPressed: () => context.push('/auth?redirect=$returnLocation'),
            ),
          ],
        ),
      ),
    );
  }
}
