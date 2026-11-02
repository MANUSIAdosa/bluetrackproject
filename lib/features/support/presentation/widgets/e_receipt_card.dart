import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../donation/domain/donation.dart';
import '../../domain/donation_trace.dart';

/// E-Receipt summary for a successful donation, or a note explaining that the
/// receipt becomes available only after the support succeeds.
class EReceiptSection extends StatelessWidget {
  const EReceiptSection({super.key, required this.trace});

  final DonationTrace trace;

  @override
  Widget build(BuildContext context) {
    if (trace.status != DonationStatus.success) {
      return _ReceiptUnavailable(status: trace.status);
    }
    return _ReceiptCard(trace: trace);
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.trace});

  final DonationTrace trace;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;

    return Container(
      key: const ValueKey('p08-receipt-card'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.ocean.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: AppColors.ocean,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('p08_receipt_title'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: trace.status),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                _ReceiptRow(
                  label: context.tr('p08_receipt_number'),
                  value: trace.receiptNumber,
                ),
                _ReceiptRow(
                  label: context.tr('p08_receipt_date'),
                  value: Formatters.date(trace.donatedAt, lang),
                ),
                _ReceiptRow(
                  label: context.tr('p08_receipt_project'),
                  value: trace.projectTitle,
                ),
                _ReceiptRow(
                  label: context.tr('p08_receipt_organization'),
                  value: trace.organization,
                ),
                _ReceiptRow(
                  label: context.tr('p08_receipt_method'),
                  value: _methodLabel(context, trace.paymentMethod),
                ),
                const SizedBox(height: 12),
                const _DashedDivider(),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ocean.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        context.tr('p08_receipt_amount'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          Formatters.currency(trace.amount, lang),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ocean,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _methodLabel(BuildContext context, PaymentMethod method) {
    return switch (method) {
      PaymentMethod.virtualAccount => context.tr('p06_confirm_method_va'),
      PaymentMethod.eWallet => context.tr('p06_confirm_method_ewallet'),
      PaymentMethod.card => context.tr('p06_confirm_method_card'),
    };
  }
}

class _ReceiptUnavailable extends StatelessWidget {
  const _ReceiptUnavailable({required this.status});

  final DonationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == DonationStatus.pending
        ? AppColors.warning
        : AppColors.danger;

    return Container(
      key: const ValueKey('p08-receipt-unavailable'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_outlined, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('p08_receipt_unavailable_title'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('p08_receipt_unavailable_body'),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                _StatusChip(status: status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value ?? '',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed rule that gives the E-Receipt a receipt-like separation before the
/// amount total.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dashWidth + gap)).floor();
        if (count <= 0) return const SizedBox(height: 1);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) =>
                Container(width: dashWidth, height: 1, color: AppColors.border),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final DonationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      DonationStatus.success => (
        context.tr('p08_receipt_status_success'),
        AppColors.success,
        Icons.check_circle_outline,
      ),
      DonationStatus.pending => (
        context.tr('p08_receipt_status_pending'),
        AppColors.warning,
        Icons.schedule,
      ),
      DonationStatus.failed => (
        context.tr('p08_receipt_status_failed'),
        AppColors.danger,
        Icons.error_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
