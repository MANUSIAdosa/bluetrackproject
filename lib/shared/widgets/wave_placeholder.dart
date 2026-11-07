import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Gallery stand-in for mock projects that carry colours instead of photos.
///
/// A gradient from [colors] with three static wave bands on top. The phase
/// comes from [seed] (the project id), so cards differ but never jitter when
/// the widget is rebuilt. No animation: the placeholder is decoration, and a
/// [RepaintBoundary] keeps it out of the list's repaint work.
class WavePlaceholder extends StatelessWidget {
  const WavePlaceholder({super.key, required this.colors, required this.seed});

  final List<String> colors;
  final String seed;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: _gradient(colors)),
        child: CustomPaint(
          painter: _WavePainter(phase: (seed.hashCode % 360) / 360),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.phase});

  /// 0…1 offset so every project starts its waves at a different point.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    for (var layer = 0; layer < 3; layer++) {
      final baseline = size.height * (0.55 + 0.14 * layer);
      final amplitude = size.height * 0.06;
      final waveLength = size.width / 2.2;
      final shift = phase * 2 * math.pi + layer * math.pi / 2;
      final path = Path()..moveTo(0, baseline);
      for (var x = 0.0; x <= size.width; x += 4) {
        final y =
            baseline +
            math.sin((x / waveLength) * 2 * math.pi + shift) * amplitude;
        path.lineTo(x, y);
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.10 + layer * 0.02)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => oldDelegate.phase != phase;
}

Color _hexToColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

/// A single colour is a valid mock entry but `LinearGradient` asserts on fewer
/// than two stops, so the colour is repeated instead of crashing the card.
LinearGradient _gradient(List<String> colors) {
  final parsed = colors.isEmpty
      ? const [AppColors.ocean, AppColors.teal]
      : colors.map(_hexToColor).toList();
  return LinearGradient(
    colors: parsed.length >= 2 ? parsed : [parsed.first, parsed.first],
  );
}
