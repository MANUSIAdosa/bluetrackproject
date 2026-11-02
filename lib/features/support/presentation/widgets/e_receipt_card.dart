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
      padding: const EdgeInsets.all(AppDimens.padding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.ocean.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: AppColors.ocean,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('p08_receipt_title'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _ReceiptRow(
            label: context.tr('p08_receipt_number'),
            value: trace.receiptNumber,
          ),
          _ReceiptRow(
            label: context.tr('p08_receipt_date'),
            value: Formatters.date(trace.donatedAt, lang),
          ),
          _ReceiptRow(
            label: context.tr('p08_receipt_amount'),
            valueWidget: Text(
              Formatters.currency(trace.amount, lang),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ocean,
              ),
            ),
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
          _ReceiptRow(
            label: context.tr('p08_receipt_status'),
            valueWidget: _StatusChip(status: trace.status),
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
          const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.textSecondary,
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
  const _ReceiptRow({required this.label, this.value, this.valueWidget});

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  valueWidget ??
                  Text(
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
          ),
        ],
      ),
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
