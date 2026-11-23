import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('measure title and label widths with the app font', (
    tester,
  ) async {
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await loader.load();

    const titleStyle = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 26,
      fontWeight: FontWeight.w800,
    );
    for (final title in ['Pilih Minatmu', 'Pick Your Interests']) {
      final painter = TextPainter(
        text: TextSpan(text: title, style: titleStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      // ignore: avoid_print
      print('title "$title" width=${painter.width} height=${painter.height}');
      painter.dispose();
    }

    const labelStyle = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    for (final label in [
      'Informasi Detail',
      'Info Detail',
      'Detail Information',
      'Detail Info',
      'Detail',
    ]) {
      final p = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      // ignore: avoid_print
      print('label12 "$label" width=${p.width} height=${p.height}');
      p.dispose();
    }

    const label11 = TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    for (final label in ['Informasi Detail', 'Detail Information']) {
      final p = TextPainter(
        text: TextSpan(text: label, style: label11),
        textDirection: TextDirection.ltr,
      )..layout();
      // ignore: avoid_print
      print('label11 "$label" width=${p.width} height=${p.height}');
      p.dispose();
    }
  });
}
