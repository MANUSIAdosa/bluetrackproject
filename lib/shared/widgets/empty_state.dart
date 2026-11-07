import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Shared empty state with icon, optional title, message and action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Second, lower-emphasis action. Only screens that offer a recovery choice
  /// fill it in; without it the state looks exactly as before.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    // SingleChildScrollView keeps this overflow-safe when the parent gives it
    // a short box (e.g. inside a NestedScrollView tab body on a small screen).
    // With enough room it lays out exactly as a plain centered Column.
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.ocean.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: AppColors.ocean),
              ),
              const SizedBox(height: 16),
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                // With a second choice the first one carries the emphasis;
                // alone it stays a text button so other pages keep their look.
                if (secondaryLabel != null && onSecondary != null)
                  FilledButton(onPressed: onAction, child: Text(actionLabel!))
                else
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                if (secondaryLabel != null && onSecondary != null)
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
