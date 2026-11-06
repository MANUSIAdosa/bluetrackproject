import 'package:blue_track/shared/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('no Material glyph flashes before the artwork has a frame', (
    tester,
  ) async {
    for (final category in CategoryIcons.categories) {
      await tester.pumpWidget(
        wrapPage(CategoryIcon(category: category, size: 24)),
      );
      // The localization delegate resolves on the next frame; the first
      // painted state must already be the neutral disc, not the fallback.
      await tester.pump();

      expect(
        find.byType(Icon),
        findsNothing,
        reason: '$category must not flash its Material glyph',
      );
      expect(find.byType(Image), findsOneWidget);
    }
  });

  test('every category has a distinct icon and colour pair', () {
    final icons = <IconData>{};
    final colors = <Color>{};

    for (final category in CategoryIcons.categories) {
      icons.add(CategoryIcons.iconFor(category));
      colors.add(CategoryIcons.colorFor(category));
    }

    expect(icons, hasLength(CategoryIcons.categories.length));
    expect(colors, hasLength(CategoryIcons.categories.length));
  });

  test('categories without artwork use their Material glyph directly', () {
    expect(CategoryIcons.assetFor('semua'), isNull);
    expect(CategoryIcons.assetFor('entah'), isNull);
    expect(CategoryIcons.iconFor('semua'), Icons.grid_view_rounded);
    expect(CategoryIcons.iconFor('entah'), Icons.waves);
  });

  testWidgets('the all-categories icon does not request a missing asset', (
    tester,
  ) async {
    await tester.pumpWidget(wrapPage(const CategoryIcon(category: 'semua')));
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
  });

  testWidgets('the icon is labelled with the localized category name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(wrapPage(const CategoryIcon(category: 'penyu')));
    await tester.pump();

    expect(
      find.bySemanticsLabel('Penyu'),
      findsOneWidget,
      reason: 'screen readers need the category, not "image"',
    );

    handle.dispose();
  });
}
