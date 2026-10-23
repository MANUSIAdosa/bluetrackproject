import 'package:blue_track/shared/widgets/category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('each sea category renders its own icon and colour', (
    tester,
  ) async {
    const categories = [
      'penyu',
      'karang',
      'mangrove',
      'mamalia_laut',
      'lamun',
    ];

    for (final category in categories) {
      await tester.pumpWidget(
        wrapPage(CategoryIcon(category: category, size: 24)),
      );
      // The localization delegate resolves on the next frame; until then
      // `Localizations` renders a placeholder instead of its child.
      await tester.pump();

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(
        icon.icon,
        CategoryIcons.iconFor(category),
        reason: 'icon for $category',
      );
      expect(
        icon.color,
        CategoryIcons.colorFor(category),
        reason: 'colour for $category',
      );
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

  test('an unknown category falls back to the generic sea icon', () {
    expect(CategoryIcons.iconFor('entah'), Icons.waves);
    expect(CategoryIcons.colorFor('entah'), isNotNull);
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
