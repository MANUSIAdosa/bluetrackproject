import 'package:flutter/material.dart';

/// A single option in a [FilterChipRow].
class ChipOption {
  const ChipOption({required this.id, required this.label, this.color});

  final String id;
  final String label;

  /// Optional category colour, shown as an 8dp dot instead of a glyph.
  final Color? color;
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
    final selected = option.id == selectedId;
    final color = option.color;

    return ChoiceChip(
      label: Text(option.label),
      selected: selected,
      showCheckmark: false,
      // The padded tap target keeps the touch area at 48dp even though the
      // chip itself is shorter; nothing clips it because the row has no fixed
      // height.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      avatar: color == null
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: Colors.white, width: 1.5)
                    : null,
              ),
            ),
      onSelected: (_) => onSelected(option.id),
    );
  }
}
