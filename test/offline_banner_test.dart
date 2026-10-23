import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/shared/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  tearDown(() => OfflineController.instance.setOffline(false));

  testWidgets('the banner is invisible while the app is online', (
    tester,
  ) async {
    await tester.pumpWidget(wrapPage(const OfflineBanner()));
    await tester.pump();

    expect(find.byIcon(Icons.cloud_off), findsNothing);
    expect(find.textContaining('offline'), findsNothing);
  });

  testWidgets('the banner explains that saved data is being shown offline', (
    tester,
  ) async {
    await tester.pumpWidget(wrapPage(const OfflineBanner()));
    await tester.pump();

    OfflineController.instance.setOffline(true);
    await tester.pump();

    expect(
      find.text('Anda sedang offline. Menampilkan data tersimpan.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('the banner disappears again when the connection returns', (
    tester,
  ) async {
    OfflineController.instance.setOffline(true);
    await tester.pumpWidget(wrapPage(const OfflineBanner()));
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);

    OfflineController.instance.setOffline(false);
    await tester.pump();

    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });
}
