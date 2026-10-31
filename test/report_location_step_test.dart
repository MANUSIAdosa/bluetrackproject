import 'dart:async';

import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/report_submit/domain/report_location.dart';
import 'package:blue_track/features/report_submit/presentation/widgets/report_location_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'support/fake_report_location_service.dart';
import 'support/fake_tile_provider.dart';
import 'support/test_harness.dart';

const _gpsKey = ValueKey('report_location_gps');
const _pinKey = ValueKey('report_location_pin_drag');
const _hintKey = ValueKey('report_location_hint');

void main() {
  late FakeReportLocationService locationService;
  late FakeTileProvider tileProvider;
  late List<LatLng> reportedLocations;

  setUp(() {
    locationService = FakeReportLocationService();
    tileProvider = FakeTileProvider();
    reportedLocations = [];
  });

  void phoneSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
  }

  Future<void> pumpStep(
    WidgetTester tester, {
    double? latitude,
    double? longitude,
  }) async {
    phoneSurface(tester);
    await tester.pumpWidget(
      wrapPage(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ReportLocationStep(
            latitude: latitude,
            longitude: longitude,
            locationService: locationService,
            tileProvider: tileProvider,
            onLocationChanged: (lat, lng) {
              reportedLocations.add(LatLng(lat, lng));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String coordinate(WidgetTester tester, String key) {
    return tester.widget<Text>(find.byKey(ValueKey(key))).data!;
  }

  Future<void> tapMap(WidgetTester tester) async {
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    // flutter_map delays single taps by 250 ms to tell them apart from double
    // taps; pump past that before settling.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the map at about 55% of the screen with a hint', (
    tester,
  ) async {
    await pumpStep(tester);

    expect(find.text('Tandai lokasi temuan'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(
      tester.getSize(find.byType(FlutterMap)).height,
      closeTo(844 * 0.55, 1),
    );
    expect(find.byKey(_hintKey), findsOneWidget);
    expect(find.text('Geser pin ke lokasi temuan'), findsOneWidget);
    expect(find.byKey(_pinKey), findsNothing);
    expect(
      find.text('Ketuk peta atau gunakan lokasi saya untuk mengisi koordinat.'),
      findsOneWidget,
    );

    final gps = find.byKey(_gpsKey);
    expect(tester.getSize(gps).height, greaterThanOrEqualTo(48));
    expect(find.text('Gunakan lokasi saya'), findsOneWidget);
  });

  testWidgets('shows the OSM attribution from the map', (tester) async {
    await pumpStep(tester);

    await tester.tap(find.byIcon(Icons.info_outlined));
    await tester.pumpAndSettle();

    expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('tap on the map places a pin and reports six decimals', (
    tester,
  ) async {
    await pumpStep(tester);

    await tapMap(tester);

    expect(reportedLocations, hasLength(1));
    expect(reportedLocations.single.latitude, closeTo(-8.5236, 0.01));
    expect(reportedLocations.single.longitude, closeTo(114.6131, 0.01));
    expect(find.byKey(_pinKey), findsOneWidget);
    expect(find.byKey(_hintKey), findsNothing);
    expect(
      coordinate(tester, 'report_location_latitude_value'),
      reportedLocations.single.latitude.toStringAsFixed(6),
    );
    expect(
      coordinate(tester, 'report_location_longitude_value'),
      reportedLocations.single.longitude.toStringAsFixed(6),
    );
  });

  testWidgets('starts on the saved draft pin without showing the hint', (
    tester,
  ) async {
    await pumpStep(tester, latitude: -6.9175, longitude: 107.6191);

    expect(find.byKey(_pinKey), findsOneWidget);
    expect(find.byKey(_hintKey), findsNothing);
    expect(coordinate(tester, 'report_location_latitude_value'), '-6.917500');
    expect(coordinate(tester, 'report_location_longitude_value'), '107.619100');

    // The pin's tip sits on the map centre, which is the saved draft point.
    final mapRect = tester.getRect(find.byType(FlutterMap));
    final pinRect = tester.getRect(find.byKey(_pinKey));
    expect(pinRect.bottomCenter.dx, closeTo(mapRect.center.dx, 0.5));
    expect(pinRect.bottom, closeTo(mapRect.center.dy, 0.5));

    // Tapping away from the pin still places it manually.
    await tester.tapAt(mapRect.center + const Offset(80, 80));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(reportedLocations, hasLength(1));
    expect(reportedLocations.single.latitude, lessThan(-6.9175));
    expect(reportedLocations.single.longitude, greaterThan(107.6191));
  });

  testWidgets('dragging the pin moves the reported location', (tester) async {
    await pumpStep(tester, latitude: -6.9175, longitude: 107.6191);

    await tester.drag(find.byKey(_pinKey), const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(reportedLocations, isNotEmpty);
    expect(reportedLocations.last.latitude, lessThan(-6.9175));
    expect(
      coordinate(tester, 'report_location_latitude_value'),
      reportedLocations.last.latitude.toStringAsFixed(6),
    );
  });

  testWidgets('uses the GPS fix and recentres the pin', (tester) async {
    locationService.result = const ReportLocationResult.success(
      latitude: -6.2,
      longitude: 106.8,
    );
    await pumpStep(tester);

    await tester.tap(find.byKey(_gpsKey));
    await tester.pumpAndSettle();

    expect(reportedLocations, hasLength(1));
    expect(reportedLocations.single.latitude, -6.2);
    expect(reportedLocations.single.longitude, 106.8);
    expect(find.byKey(_pinKey), findsOneWidget);
    expect(find.byKey(_hintKey), findsNothing);
    expect(coordinate(tester, 'report_location_latitude_value'), '-6.200000');
    expect(coordinate(tester, 'report_location_longitude_value'), '106.800000');
  });

  testWidgets('shows GPS loading inside the button, never full screen', (
    tester,
  ) async {
    final completer = Completer<ReportLocationResult>();
    locationService.pending = completer;
    await pumpStep(tester);

    await tester.tap(find.byKey(_gpsKey));
    await tester.pump();

    expect(find.text('Mengambil lokasi...'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_gpsKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(_gpsKey)).onPressed,
      isNull,
    );

    completer.complete(
      const ReportLocationResult.success(latitude: -6.2, longitude: 106.8),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mengambil lokasi...'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Gunakan lokasi saya'), findsOneWidget);
  });

  const failureMessages = [
    (ReportLocationFailure.permissionDenied, 'Izin lokasi ditolak'),
    (ReportLocationFailure.permissionDeniedForever, 'Izin lokasi diblokir'),
    (ReportLocationFailure.serviceDisabled, 'Layanan lokasi mati'),
    (ReportLocationFailure.timeout, 'GPS tidak merespons'),
    (ReportLocationFailure.unavailable, 'Lokasi tidak dapat diambil'),
  ];

  for (final (failure, message) in failureMessages) {
    testWidgets('${failure.name} keeps the manual map usable', (tester) async {
      locationService.result = ReportLocationResult.failed(failure);
      await pumpStep(tester);

      await tester.tap(find.byKey(_gpsKey));
      await tester.pumpAndSettle();

      expect(find.text('Lokasi tidak tersedia'), findsOneWidget);
      expect(find.textContaining(message), findsOneWidget);

      await tester.tap(find.text('Tandai manual'));
      await tester.pumpAndSettle();

      await tapMap(tester);
      expect(find.byKey(_pinKey), findsOneWidget);
      expect(reportedLocations, isNotEmpty);
    });
  }

  testWidgets('permanently denied permission offers the app settings', (
    tester,
  ) async {
    locationService.result = const ReportLocationResult.failed(
      ReportLocationFailure.permissionDeniedForever,
    );
    await pumpStep(tester);

    await tester.tap(find.byKey(_gpsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka pengaturan'));
    await tester.pumpAndSettle();

    expect(locationService.appSettingsCalls, 1);
    expect(locationService.locationSettingsCalls, 0);
    expect(find.text('Lokasi tidak tersedia'), findsNothing);

    await tapMap(tester);
    expect(reportedLocations, isNotEmpty);
  });

  testWidgets('disabled location services offer the system settings', (
    tester,
  ) async {
    locationService.result = const ReportLocationResult.failed(
      ReportLocationFailure.serviceDisabled,
    );
    await pumpStep(tester);

    await tester.tap(find.byKey(_gpsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka pengaturan lokasi'));
    await tester.pumpAndSettle();

    expect(locationService.locationSettingsCalls, 1);
    expect(locationService.appSettingsCalls, 0);
  });

  testWidgets('explains when the settings screen cannot be opened', (
    tester,
  ) async {
    locationService
      ..result = const ReportLocationResult.failed(
        ReportLocationFailure.permissionDeniedForever,
      )
      ..appSettingsResult = false;
    await pumpStep(tester);

    await tester.tap(find.byKey(_gpsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka pengaturan'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Pengaturan tidak dapat dibuka'),
      findsOneWidget,
    );
  });

  testWidgets('offline hides the tile layer but keeps the pin usable', (
    tester,
  ) async {
    OfflineController.instance.setOffline(true);
    addTearDown(() => OfflineController.instance.setOffline(false));
    await pumpStep(tester);

    expect(find.byType(TileLayer), findsNothing);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(_hintKey), findsOneWidget);

    await tapMap(tester);

    expect(reportedLocations, isNotEmpty);
    expect(find.byKey(_pinKey), findsOneWidget);
    expect(
      coordinate(tester, 'report_location_latitude_value'),
      reportedLocations.single.latitude.toStringAsFixed(6),
    );
  });
}
