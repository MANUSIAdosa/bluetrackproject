import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// One row inside a [DonationSummaryCard].
class DonationSummaryItem {
  const DonationSummaryItem({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;
}

/// Card with label/value rows shared by the confirmation and result screens.
class DonationSummaryCard extends StatelessWidget {
  const DonationSummaryCard({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<DonationSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              _SummaryRow(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.item});

  final DonationSummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(
            item.label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            item.value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: item.emphasize ? 16 : 13,
              fontWeight: item.emphasize ? FontWeight.w700 : FontWeight.w600,
              color: item.emphasize ? AppColors.coral : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
