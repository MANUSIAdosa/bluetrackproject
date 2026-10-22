import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/donation.dart';

/// Required payment-method picker for the confirmation step.
class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.errorText,
  });

  final PaymentMethod? selected;
  final ValueChanged<PaymentMethod> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('p06_confirm_method'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            RadioGroup<PaymentMethod>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
              child: Column(
                children: [
                  _MethodTile(
                    method: PaymentMethod.virtualAccount,
                    labelKey: 'p06_confirm_method_va',
                    icon: Icons.account_balance_outlined,
                  ),
                  _MethodTile(
                    method: PaymentMethod.eWallet,
                    labelKey: 'p06_confirm_method_ewallet',
                    icon: Icons.wallet_outlined,
                  ),
                  _MethodTile(
                    method: PaymentMethod.card,
                    labelKey: 'p06_confirm_method_card',
                    icon: Icons.credit_card,
                  ),
                ],
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 4),
              Text(
                errorText!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.labelKey,
    required this.icon,
  });

  final PaymentMethod method;
  final String labelKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<PaymentMethod>(
      value: method,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      secondary: Icon(icon, color: AppColors.ocean),
      activeColor: AppColors.ocean,
      title: Text(
        context.tr(labelKey),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}
