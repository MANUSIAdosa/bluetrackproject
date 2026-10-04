import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Numbered step indicator used by auth (P02) and donation (P06).
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.labels,
    required this.current,
  });

  /// Labels for each step (already localized by the caller).
  final List<String> labels;

  /// Zero-based index of the active step.
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          // One unit per step: number + label grouped together. The group is
          // Flexible so the label receives a bounded width and can ellipsize
          // on narrow screens; a non-flexible min-size Row would overflow.
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepDot(index: i, active: i == current, done: i < current),
                const SizedBox(width: 6),
                _StepLabel(
                  label: labels[i],
                  active: i == current,
                ),
              ],
            ),
          ),
          // Connector sits between steps, never between a dot and its label.
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: i < current ? AppColors.ocean : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.active, required this.done});

  final int index;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = active || done ? AppColors.ocean : AppColors.border;
    final textColor = active || done ? Colors.white : AppColors.textSecondary;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: done
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? AppColors.ocean : AppColors.textSecondary,
        ),
      ),
    );
  }
}
