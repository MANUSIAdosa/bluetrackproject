import 'package:blue_track/features/explore/presentation/widgets/category_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

Future<void> openPicker(WidgetTester tester, {String selected = 'penyu'}) async {
  await tester.pumpWidget(
    wrapPage(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showCategoryPickerSheet(
            context,
            categoryIds: const ['semua', 'penyu', 'karang', 'mangrove'],
            selectedId: selected,
          ),
          child: const Text('buka'),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the map category picker is a vertical list, not a grid', (
    tester,
  ) async {
    await openPicker(tester);

    expect(find.byKey(const ValueKey('explore.categoryPicker')), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Penyu'), findsOneWidget);
    expect(find.text('Karang'), findsOneWidget);
    expect(find.text('Mangrove'), findsOneWidget);
  });

  testWidgets('tapping a list row returns the chosen category', (tester) async {
    String? picked;
    await tester.pumpWidget(
      wrapPage(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              picked = await showCategoryPickerSheet(
                context,
                categoryIds: const ['semua', 'penyu', 'karang'],
                selectedId: 'penyu',
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('explore.categoryPicker.karang')),
    );
    await tester.pumpAndSettle();

    expect(picked, 'karang');
  });
}
