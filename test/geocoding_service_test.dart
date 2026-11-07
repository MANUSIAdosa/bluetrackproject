import 'dart:convert';

import 'package:blue_track/features/report_submit/data/geocoding_service.dart';
import 'package:blue_track/features/report_submit/domain/geocoding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('search parses Nominatim results and identifies the app', () async {
    late http.Request captured;
    final service = NominatimGeocodingService(
      client: MockClient((request) async {
        captured = request;
        return _json([
          {
            'display_name': 'Pantai Sukamade, Banyuwangi',
            'lat': '-8.5236',
            'lon': '114.6131',
          },
        ]);
      }),
      wait: (_) async {},
    );

    final result = await service.search('Pantai Sukamade', languageCode: 'id');

    expect(result.hasPlaces, isTrue);
    expect(result.places.single.displayName, 'Pantai Sukamade, Banyuwangi');
    expect(result.places.single.latitude, closeTo(-8.5236, 0.0001));
    expect(result.places.single.longitude, closeTo(114.6131, 0.0001));
    expect(captured.url.host, 'nominatim.openstreetmap.org');
    expect(captured.url.path, '/search');
    expect(captured.url.queryParameters['q'], 'Pantai Sukamade');
    expect(captured.url.queryParameters['format'], 'jsonv2');
    expect(captured.url.queryParameters['limit'], '5');
    expect(captured.url.queryParameters['accept-language'], 'id');
    expect(captured.headers['User-Agent'], contains('BlueTrack'));
  });

  test('reverse reads the area name for the pin', () async {
    late http.Request captured;
    final service = NominatimGeocodingService(
      client: MockClient((request) async {
        captured = request;
        return _json({
          'display_name': 'Taman Nasional Meru Betiri, Jawa Timur',
          'lat': '-8.5236',
          'lon': '114.6131',
        });
      }),
      wait: (_) async {},
    );

    final result = await service.reverse(
      latitude: -8.5236,
      longitude: 114.6131,
      languageCode: 'id',
    );

    expect(result.hasPlace, isTrue);
    expect(result.place!.displayName, 'Taman Nasional Meru Betiri, Jawa Timur');
    expect(captured.url.path, '/reverse');
    expect(captured.url.queryParameters['lat'], '-8.5236');
    expect(captured.url.queryParameters['lon'], '114.6131');
    expect(captured.url.queryParameters['zoom'], '14');
  });

  test('maps an empty result list to guidance instead of an error', () async {
    final service = NominatimGeocodingService(
      client: MockClient((_) async => _json(const [])),
      wait: (_) async {},
    );

    final result = await service.search('tempat yang tidak ada');

    expect(result.hasPlaces, isFalse);
    expect(result.failure, GeocodingFailure.empty);
  });

  test('reports rate limiting separately from a generic failure', () async {
    final service = NominatimGeocodingService(
      client: MockClient((_) async => http.Response('slow down', 429)),
      wait: (_) async {},
    );

    final result = await service.search('Pantai');

    expect(result.failure, GeocodingFailure.rateLimited);
  });

  test('reports a timeout when Nominatim does not answer in time', () async {
    final service = NominatimGeocodingService(
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return _json(const []);
      }),
      timeout: const Duration(milliseconds: 20),
      wait: (_) async {},
    );

    final result = await service.reverse(latitude: -8.5, longitude: 114.6);

    expect(result.failure, GeocodingFailure.timeout);
  });

  test('spaces requests at least 1.1 seconds apart', () async {
    var now = DateTime.utc(2026, 11, 6, 9);
    final waits = <Duration>[];
    final service = NominatimGeocodingService(
      client: MockClient((_) async => _json(const [])),
      wait: (duration) async {
        waits.add(duration);
        now = now.add(duration);
      },
      now: () => now,
    );

    await service.search('pertama');
    await service.search('kedua');

    expect(waits, hasLength(1));
    expect(waits.single, const Duration(milliseconds: 1100));
  });
}
