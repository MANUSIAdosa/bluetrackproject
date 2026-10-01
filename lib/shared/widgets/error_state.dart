import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'empty_state.dart';

/// Shared error state with retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.message, this.onRetry});

  /// Defaults to the localized generic retry message.
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      message: message ?? context.tr('common.errorRetry'),
      actionLabel: context.tr('common.retry'),
      onAction: onRetry,
    );
  }
}

/// Shows a localized retry snackbar (network-style errors inside flows).
void showErrorSnackbar(BuildContext context, {String? message}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message ?? context.tr('common.errorRetry')),
        action: SnackBarAction(
          label: context.tr('common.retry'),
          textColor: AppColors.teal,
          onPressed: () {},
        ),
      ),
    );
}
