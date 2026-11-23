import 'package:blue_track/features/explore/presentation/widgets/explore_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets('map category chip tap target', (tester) async {
    await tester.pumpWidget(
      wrapPage(
        ExploreResultsBar(
          count: 6,
          mapMode: true,
          categoryId: 'penyu',
          onCategoryPressed: () {},
          onViewChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    final chip = find.byKey(const ValueKey('explore.mapCategoryChip'));
    // ignore: avoid_print
    print('CHIP ${tester.getSize(chip)}');
    // ignore: avoid_print
    print('TAP ${tester.getSize(find.byType(ActionChip))}');
  });
}
