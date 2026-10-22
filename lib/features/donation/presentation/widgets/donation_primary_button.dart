import 'package:flutter/material.dart';

import '../../../../shared/widgets/primary_button.dart';

/// Coral primary CTA for P06 with the 12 dp button radius from the UI rules.
///
/// The shared [PrimaryButton] keeps its coral fill, 52 dp height and loading
/// state; only the radius is overridden locally because the global theme still
/// uses the 16 dp card radius for buttons and shared widgets must not be
/// changed from this feature.
class DonationPrimaryButton extends StatelessWidget {
  const DonationPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.filledButtonTheme.style ?? const ButtonStyle();
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: base.copyWith(
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ),
      ),
      child: PrimaryButton(
        label: label,
        onPressed: onPressed,
        loading: loading,
        icon: icon,
      ),
    );
  }
}
