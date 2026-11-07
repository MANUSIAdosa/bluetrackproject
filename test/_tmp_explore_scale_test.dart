import 'package:blue_track/features/explore/domain/project.dart';
import 'package:blue_track/features/explore/presentation/explore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/test_harness.dart';

List<Project> _projects() => [
  buildProject(id: 'p01', title: 'Penyu Hijau', category: 'penyu'),
  buildProject(id: 'p02', title: 'Karang Razak', category: 'karang'),
  buildProject(id: 'p03', title: 'Mangrove Muara', category: 'mangrove'),
];

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double scale,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapPage(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: ExplorePage(
          projectRepository: FakeProjectRepository(_projects()),
          filterRepository: FakeFilterRepository(const [
            'semua',
            'penyu',
            'karang',
            'mangrove',
            'mamalia_laut',
            'lamun',
          ]),
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final size in const [Size(320, 568), Size(360, 640), Size(390, 844)]) {
    for (final scale in const [1.0, 1.3, 1.5, 1.8, 2.0]) {
      testWidgets('$size scale $scale', (tester) async {
        await _pump(tester, size: size, scale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
