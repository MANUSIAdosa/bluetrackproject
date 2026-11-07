import 'dart:async';

import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/report_submit/data/geocoding_service.dart';
import 'package:blue_track/features/report_submit/domain/geocoding.dart';
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
const _addressFieldKey = ValueKey('report_address_field');
const _addressSearchKey = ValueKey('report_address_search');
const _addressSheetSearchKey = ValueKey('report_address_sheet_search');

class _FakeGeocodingService implements GeocodingService {
  GeocodingSearchResult searchResult = const GeocodingSearchResult.failed(
    GeocodingFailure.empty,
  );
  GeocodingPlaceResult reverseResult = const GeocodingPlaceResult.failed(
    GeocodingFailure.empty,
  );

  int searchCalls = 0;
  int reverseCalls = 0;
  String? lastQuery;
  double? lastLatitude;
  double? lastLongitude;

  @override
  Future<GeocodingSearchResult> search(
    String query, {
    String languageCode = 'id',
  }) async {
    searchCalls++;
    lastQuery = query;
    return searchResult;
  }

  @override
  Future<GeocodingPlaceResult> reverse({
    required double latitude,
    required double longitude,
    String languageCode = 'id',
  }) async {
    reverseCalls++;
    lastLatitude = latitude;
    lastLongitude = longitude;
    return reverseResult;
  }
}

void main() {
  late FakeReportLocationService locationService;
  late FakeTileProvider tileProvider;
  late List<LatLng> reportedLocations;
  late List<String> reportedLocationDetails;
  late List<String> reportedAreaNames;

  setUp(() {
    locationService = FakeReportLocationService();
    tileProvider = FakeTileProvider();
    reportedLocations = [];
    reportedLocationDetails = [];
    reportedAreaNames = [];
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
    String locationDetail = '',
    String areaName = '',
    GeocodingService? geocoding,
  }) async {
    phoneSurface(tester);
    await tester.pumpWidget(
      wrapPage(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ReportLocationStep(
            latitude: latitude,
            longitude: longitude,
            locationDetail: locationDetail,
            areaName: areaName,
            geocodingService: geocoding ?? _FakeGeocodingService(),
            locationService: locationService,
            tileProvider: tileProvider,
            onLocationChanged: (lat, lng) {
              reportedLocations.add(LatLng(lat, lng));
            },
            onLocationDetailChanged: reportedLocationDetails.add,
            onAreaChanged: reportedAreaNames.add,
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
      find.text('Tandai pin dulu untuk melihat nama area.'),
      findsOneWidget,
    );

    final gps = find.byKey(_gpsKey);
    expect(tester.getSize(gps).height, greaterThanOrEqualTo(48));
    expect(find.text('Lokasi saya'), findsOneWidget);
    expect(find.byTooltip('Gunakan lokasi saya'), findsOneWidget);
  });

  testWidgets('lets the reporter enter an optional nearby landmark', (
    tester,
  ) async {
    await pumpStep(tester, locationDetail: 'Near the north pier.');

    final field = find.byKey(const ValueKey('report_location_detail_field'));
    expect(field, findsOneWidget);
    expect(
      tester.widget<TextField>(field).controller?.text,
      'Near the north pier.',
    );

    await tester.ensureVisible(field);
    await tester.enterText(
      field,
      'About 2 nautical miles north of the island.',
    );
    expect(reportedLocationDetails, [
      'About 2 nautical miles north of the island.',
    ]);
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

    expect(find.text('Mengambil...'), findsOneWidget);
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

    expect(find.text('Mengambil...'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Lokasi saya'), findsOneWidget);
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

  testWidgets('names the area without writing into the landmark', (
    tester,
  ) async {
    final geocoding = _FakeGeocodingService()
      ..reverseResult = const GeocodingPlaceResult.success(
        GeocodingPlace(
          displayName: 'Pantai Sukamade, Banyuwangi',
          latitude: -8.5236,
          longitude: 114.6131,
        ),
      );
    await pumpStep(
      tester,
      latitude: -8.5236,
      longitude: 114.6131,
      geocoding: geocoding,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Pantai Sukamade, Banyuwangi'), findsOneWidget);
    expect(find.text('Data © OpenStreetMap contributors'), findsOneWidget);
    expect(geocoding.reverseCalls, 1);
    expect(geocoding.lastLatitude, -8.5236);
    expect(reportedAreaNames.last, 'Pantai Sukamade, Banyuwangi');
    expect(reportedLocationDetails, isEmpty);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('report_location_detail_field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('never overwrites a landmark the reporter typed', (tester) async {
    final geocoding = _FakeGeocodingService()
      ..reverseResult = const GeocodingPlaceResult.success(
        GeocodingPlace(
          displayName: 'Pantai Sukamade, Banyuwangi',
          latitude: -8.5236,
          longitude: 114.6131,
        ),
      );
    await pumpStep(
      tester,
      latitude: -8.5236,
      longitude: 114.6131,
      locationDetail: 'Dekat dermaga utara',
      geocoding: geocoding,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(reportedLocationDetails, isEmpty);
    expect(reportedAreaNames.last, 'Pantai Sukamade, Banyuwangi');
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('report_location_detail_field')),
          )
          .controller
          ?.text,
      'Dekat dermaga utara',
    );
  });

  testWidgets('searching an address moves the pin to the chosen result', (
    tester,
  ) async {
    final geocoding = _FakeGeocodingService()
      ..searchResult = const GeocodingSearchResult.success([
        GeocodingPlace(
          displayName: 'Taman Nasional Meru Betiri',
          latitude: -8.6,
          longitude: 113.9,
        ),
      ]);
    await pumpStep(tester, geocoding: geocoding);

    final openSearch = find.byKey(_addressSearchKey);
    await tester.ensureVisible(openSearch);
    await tester.pumpAndSettle();
    await tester.tap(openSearch);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_addressFieldKey), 'Meru Betiri');
    await tester.tap(find.byKey(_addressSheetSearchKey));
    await tester.pumpAndSettle();

    expect(geocoding.lastQuery, 'Meru Betiri');
    final result = find.byKey(const ValueKey('report_address_result_0'));
    expect(result, findsOneWidget);

    await tester.tap(result);
    await tester.pumpAndSettle();

    expect(reportedLocations, isNotEmpty);
    expect(reportedLocations.last.latitude, closeTo(-8.6, 0.0001));
    expect(reportedLocations.last.longitude, closeTo(113.9, 0.0001));
    expect(find.text('Taman Nasional Meru Betiri'), findsWidgets);
    expect(reportedAreaNames.last, 'Taman Nasional Meru Betiri');
    expect(reportedLocationDetails, isEmpty);
  });

  testWidgets('offline disables both lookups and explains why', (tester) async {
    OfflineController.instance.setOffline(true);
    addTearDown(() => OfflineController.instance.setOffline(false));
    await pumpStep(tester, latitude: -8.5, longitude: 114.6);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Nama area butuh koneksi internet.'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(_addressSearchKey)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(_gpsKey)).onPressed,
      isNull,
    );
    expect(find.textContaining('Lokasi saya butuh'), findsNothing);
    expect(
      find.text('Pencarian lokasi butuh koneksi internet.'),
      findsOneWidget,
    );
  });

  testWidgets('aligns the empty hint with the pin icon', (tester) async {
    await pumpStep(tester);

    final icon = tester.getRect(find.byKey(const ValueKey('report_area_icon')));
    final hint = tester.getRect(
      find.text('Tandai pin dulu untuk melihat nama area.'),
    );

    expect((icon.center.dy - hint.center.dy).abs(), lessThan(2));
  });

  testWidgets('names the area again after the pin moves', (tester) async {
    final geocoding = _FakeGeocodingService()
      ..reverseResult = const GeocodingPlaceResult.success(
        GeocodingPlace(
          displayName: 'Pantai Sukamade, Banyuwangi',
          latitude: -8.5236,
          longitude: 114.6131,
        ),
      );
    await pumpStep(
      tester,
      latitude: -8.5236,
      longitude: 114.6131,
      geocoding: geocoding,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(geocoding.reverseCalls, 1);

    // Dragging the pin to a new point must refresh the name on its own.
    await tester.drag(find.byKey(_pinKey), const Offset(0, 60));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(geocoding.reverseCalls, 2);
  });

  testWidgets('drops the old area name when the new point is not found', (
    tester,
  ) async {
    final geocoding = _FakeGeocodingService()
      ..reverseResult = const GeocodingPlaceResult.success(
        GeocodingPlace(
          displayName: 'Pantai Sukamade, Banyuwangi',
          latitude: -8.5,
          longitude: 114.6,
        ),
      );
    await pumpStep(
      tester,
      latitude: -8.5,
      longitude: 114.6,
      geocoding: geocoding,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Pantai Sukamade, Banyuwangi'), findsOneWidget);

    geocoding.reverseResult = const GeocodingPlaceResult.failed(
      GeocodingFailure.empty,
    );
    await tester.drag(find.byKey(_pinKey), const Offset(0, 60));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Pantai Sukamade, Banyuwangi'), findsNothing);
    expect(find.byKey(const ValueKey('report_area_error')), findsOneWidget);
    expect(reportedAreaNames.last, isEmpty);
  });

  testWidgets('shows full-width labels without truncating them', (
    tester,
  ) async {
    await pumpStep(tester);

    expect(find.text('Lokasi saya'), findsOneWidget);
    expect(find.text('Cari'), findsOneWidget);
    expect(find.byTooltip('Gunakan lokasi saya'), findsOneWidget);
  });

  testWidgets('offers a retry when the area lookup fails', (tester) async {
    final geocoding = _FakeGeocodingService()
      ..reverseResult = const GeocodingPlaceResult.failed(
        GeocodingFailure.timeout,
      );
    await pumpStep(
      tester,
      latitude: -8.5,
      longitude: 114.6,
      geocoding: geocoding,
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('report_area_error')), findsOneWidget);
    final retry = find.byKey(const ValueKey('report_area_retry'));
    expect(retry, findsOneWidget);

    geocoding.reverseResult = const GeocodingPlaceResult.success(
      GeocodingPlace(
        displayName: 'Pantai Sukamade, Banyuwangi',
        latitude: -8.5,
        longitude: 114.6,
      ),
    );
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.text('Pantai Sukamade, Banyuwangi'), findsOneWidget);
  });

  testWidgets('explains a rate-limited search and keeps the pin usable', (
    tester,
  ) async {
    final geocoding = _FakeGeocodingService()
      ..searchResult = const GeocodingSearchResult.failed(
        GeocodingFailure.rateLimited,
      );
    await pumpStep(tester, geocoding: geocoding);

    final openSearch = find.byKey(_addressSearchKey);
    await tester.ensureVisible(openSearch);
    await tester.pumpAndSettle();
    await tester.tap(openSearch);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_addressFieldKey), 'Pantai');
    await tester.tap(find.byKey(_addressSheetSearchKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.'),
      findsOneWidget,
    );

    // The sheet is modal, so close it before touching the map again.
    await tester.tap(find.byKey(const ValueKey('report_address_sheet_close')));
    await tester.pumpAndSettle();
    await tapMap(tester);
    expect(reportedLocations, isNotEmpty);
  });
}
