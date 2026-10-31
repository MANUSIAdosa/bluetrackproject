import 'dart:io';

import 'package:blue_track/core/router/app_router.dart';
import 'package:blue_track/features/report_submit/data/report_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'support/test_harness.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bluetrack_report_route_');
    Hive.init(tempDir.path);
    // Open the box outside the fake-async zone so the page's lazy load can
    // read it without real file IO inside testWidgets.
    await Hive.openBox<dynamic>(HiveReportDraftStore.boxName);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets('the /report route opens the Lapor Temuan wizard', (
    tester,
  ) async {
    final router = createRouter(onboardingDone: true);
    addTearDown(router.dispose);
    router.go('/report');

    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();

    expect(find.text('Lapor Temuan'), findsOneWidget);
    expect(find.text('Tambah Foto'), findsOneWidget);
  });

  testWidgets('Profile exposes a working Lapor Temuan entry', (tester) async {
    final router = createRouter(onboardingDone: true);
    addTearDown(router.dispose);
    router.go('/profile');

    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();

    expect(find.text('Lapor Temuan'), findsOneWidget);

    await tester.tap(find.text('Lapor Temuan'));
    await tester.pumpAndSettle();

    expect(find.text('Tambah Foto'), findsOneWidget);
  });
}
