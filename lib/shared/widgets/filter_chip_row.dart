import 'package:flutter/material.dart';

/// A single option in a [FilterChipRow].
class ChipOption {
  const ChipOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Horizontally scrollable single-select chip row.
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

  /// Horizontal inset.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            _option(options[index]),
          ],
        ],
      ),
    );
  }

  Widget _option(ChipOption option) {
    return ChoiceChip(
      label: Text(option.label),
      selected: option.id == selectedId,
      showCheckmark: false,
      // The padded tap target keeps the touch area at 48dp even though the
      // chip itself is shorter; nothing clips it because the row has no fixed
      // height.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: (_) => onSelected(option.id),
    );
  }
}
