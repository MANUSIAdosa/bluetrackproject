import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/shared/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_connectivity_service.dart';
import 'support/test_harness.dart';

void main() {
  late FakeConnectivityService connectivity;

  setUp(() {
    connectivity = FakeConnectivityService();
    OfflineController.instance.setOffline(false);
  });

  tearDown(() async {
    await OfflineController.instance.stop();
    await connectivity.close();
    OfflineController.instance.setOffline(false);
  });

  test('start marks the app offline when there is no network link', () async {
    connectivity.online = false;

    await OfflineController.instance.start(service: connectivity);

    expect(connectivity.checkCalls, 1);
    expect(OfflineController.instance.offline, isTrue);
  });

  test('start keeps the app online when a link exists', () async {
    await OfflineController.instance.start(service: connectivity);

    expect(connectivity.checkCalls, 1);
    expect(OfflineController.instance.offline, isFalse);
  });

  test('network changes flip the app between offline and online', () async {
    await OfflineController.instance.start(service: connectivity);
    expect(OfflineController.instance.offline, isFalse);

    connectivity.emit(false);
    await pumpEventQueue();
    expect(OfflineController.instance.offline, isTrue);

    connectivity.emit(true);
    await pumpEventQueue();
    expect(OfflineController.instance.offline, isFalse);
  });

  test('start is idempotent and never subscribes twice', () async {
    await OfflineController.instance.start(service: connectivity);
    await OfflineController.instance.start(service: connectivity);

    expect(connectivity.checkCalls, 1);
  });

  test('a failed platform check keeps the state and still listens', () async {
    connectivity.throwsOnCheck = true;

    await OfflineController.instance.start(service: connectivity);

    expect(OfflineController.instance.offline, isFalse);

    connectivity.emit(false);
    await pumpEventQueue();
    expect(OfflineController.instance.offline, isTrue);
  });

  test('stop cancels the subscription', () async {
    await OfflineController.instance.start(service: connectivity);
    await OfflineController.instance.stop();

    connectivity.emit(false);
    await pumpEventQueue();

    expect(OfflineController.instance.offline, isFalse);
  });

  testWidgets('the offline banner follows real connectivity changes', (
    tester,
  ) async {
    connectivity.online = true;
    await OfflineController.instance.start(service: connectivity);

    await tester.pumpWidget(wrapPage(const OfflineBanner()));
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsNothing);

    connectivity.emit(false);
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(
      find.text('Anda sedang offline. Menampilkan data tersimpan.'),
      findsOneWidget,
    );

    connectivity.emit(true);
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });
}
