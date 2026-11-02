import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// One milestone shown by [DonationTimeline].
@immutable
class DonationTimelineStep {
  const DonationTimelineStep({
    required this.label,
    required this.isComplete,
    this.timeLabel,
  });

  /// Localized milestone name.
  final String label;

  /// Whether the milestone has already happened.
  final bool isComplete;

  /// Localized date/time for a completed milestone. Pending milestones pass
  /// null and render gray without a date.
  final String? timeLabel;
}

/// Reusable vertical timeline for donation milestones.
///
/// The widget only lays out the steps it is given: labels and dates are
/// already localized by the caller, so another feature can reuse it without
/// depending on the donation domain. Pending steps keep their label but lose
/// the date and use gray dots/connectors.
class DonationTimeline extends StatelessWidget {
  const DonationTimeline({super.key, required this.steps});

  final List<DonationTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(
            key: ValueKey('donationTimeline.step.$i'),
            index: i,
            step: steps[i],
            last: i == steps.length - 1,
            nextComplete: i + 1 < steps.length && steps[i + 1].isComplete,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    super.key,
    required this.index,
    required this.step,
    required this.last,
    required this.nextComplete,
  });

  final int index;
  final DonationTimelineStep step;
  final bool last;
  final bool nextComplete;

  @override
  Widget build(BuildContext context) {
    final done = step.isComplete;
    // A connector is ocean only when the next milestone is also complete;
    // everything ahead of the donation's progress stays gray.
    final connectorColor = done && nextComplete
        ? AppColors.ocean
        : AppColors.border;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  key: ValueKey('donationTimeline.dot.$index'),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done ? AppColors.ocean : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done ? AppColors.ocean : AppColors.inactiveTab,
                      width: 2,
                    ),
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.inactiveTab,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      key: ValueKey('donationTimeline.connector.$index'),
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: connectorColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: done ? FontWeight.w700 : FontWeight.w600,
                      height: 1.3,
                      color: done
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (step.timeLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      step.timeLabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
