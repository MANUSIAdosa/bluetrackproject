import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Primary CTA button with a built-in loading state.
///
/// Coral is reserved for the single primary action of a screen, so the color is
/// declared here instead of in the shared theme.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.expand = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Optional leading icon, replacing `FilledButton.icon` at call sites that
  /// need one. Null keeps the original label-only button, so existing call
  /// sites render unchanged.
  final IconData? icon;

  /// When true, stretches to the full width (default FilledButton behavior
  /// from the theme already handles this; kept for clarity at call sites).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: AppColors.coral,
      foregroundColor: Colors.white,
    );

    final Widget button;
    if (loading) {
      button = FilledButton(
        style: style,
        onPressed: null,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      );
    } else if (icon != null) {
      button = FilledButton.icon(
        style: style,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    } else {
      button = FilledButton(
        style: style,
        onPressed: onPressed,
        child: Text(label),
      );
    }

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
