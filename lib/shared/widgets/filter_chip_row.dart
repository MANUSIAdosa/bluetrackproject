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
  });

  final List<ChipOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
