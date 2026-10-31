import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Numbered step indicator used by the report wizard and donation flow (P06).
///
/// Labels sit **below** their dot and every step gets an equal share of the
/// width. An earlier inline layout put the label beside the dot, where labels
/// competed with the connector lines for space and ellipsized on phone widths.
class StepIndicator extends StatelessWidget {
  const StepIndicator({super.key, required this.labels, required this.current});

  /// Labels for each step (already localized by the caller).
  final List<String> labels;

  /// Zero-based index of the active step.
  final int current;

  static const double _dotSize = 28;
  static const double _labelGap = 6;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: _StepColumn(
              index: i,
              label: labels[i],
              current: current,
              isFirst: i == 0,
              isLast: i == labels.length - 1,
            ),
          ),
      ],
    );
  }
}

class _StepColumn extends StatelessWidget {
  const _StepColumn({
    required this.index,
    required this.label,
    required this.current,
    required this.isFirst,
    required this.isLast,
  });

  final int index;
  final String label;
  final int current;
  final bool isFirst;
  final bool isLast;

  bool get _active => index == current;
  bool get _done => index < current;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: StepIndicator._dotSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Two half-lines per column. Neighbouring halves meet at the
              // column edge, so the track looks continuous without measuring
              // the layout.
              Row(
                children: [
                  Expanded(
                    child: isFirst
                        ? const SizedBox.shrink()
                        : _ConnectorLine(filled: index <= current),
                  ),
                  const SizedBox(width: StepIndicator._dotSize),
                  Expanded(
                    child: isLast
                        ? const SizedBox.shrink()
                        : _ConnectorLine(filled: index < current),
                  ),
                ],
              ),
              _StepDot(index: index, active: _active, done: _done),
            ],
          ),
        ),
        const SizedBox(height: StepIndicator._labelGap),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.25,
            fontWeight: _active ? FontWeight.w700 : FontWeight.w500,
            color: _active ? AppColors.ocean : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  const _ConnectorLine({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      color: filled ? AppColors.ocean : AppColors.border,
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.active,
    required this.done,
  });

  final int index;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = active || done ? AppColors.ocean : AppColors.border;
    final textColor = active || done ? Colors.white : AppColors.textSecondary;
    return Container(
      width: StepIndicator._dotSize,
      height: StepIndicator._dotSize,
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
