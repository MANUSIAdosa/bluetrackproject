import 'package:flutter/material.dart';

/// A single option in a [FilterChipRow].
class ChipOption {
  const ChipOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Horizontally scrollable single-select chip row (Explore categories).
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<ChipOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;

  /// Horizontal inset. Explore passes a left-only inset so the row bleeds to
  /// the screen edge and the next chip peeks as a scroll hint.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          return ChoiceChip(
            label: Text(option.label),
            selected: option.id == selectedId,
            showCheckmark: false,
            onSelected: (_) => onSelected(option.id),
          );
        },
      ),
    );
  }
}
