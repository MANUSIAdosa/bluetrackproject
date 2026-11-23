import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../domain/geocoding.dart';

/// Geocoding used by the report location step.
///
/// The step depends on this interface so widget tests answer deterministically
/// and a different provider can replace Nominatim without touching the page.
abstract interface class GeocodingService {
  /// Up to [NominatimGeocodingService.maxResults] places matching [query].
  Future<GeocodingSearchResult> search(
    String query, {
    String languageCode = 'id',
  });

  /// The name of the area around the given coordinates.
  Future<GeocodingPlaceResult> reverse({
    required double latitude,
    required double longitude,
    String languageCode = 'id',
  });
}

/// Public Nominatim implementation.
///
/// Public Nominatim allows at most one request per second, requires an
/// application-identifying User-Agent (browsers forbid that header, so the web
/// build relies on the automatic Referer), and expects attribution in the UI.
/// Every call here is user-triggered; nothing is sent while typing.
class NominatimGeocodingService implements GeocodingService {
  NominatimGeocodingService({
    http.Client? client,
    Uri? baseUri,
    this.timeout = const Duration(seconds: 8),
    this.minInterval = const Duration(milliseconds: 1100),
    this.userAgent = 'BlueTrack/0.1 (student project)',
    Future<void> Function(Duration)? wait,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       baseUri = baseUri ?? Uri.parse('https://nominatim.openstreetmap.org'),
       _wait = wait ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  /// Nominatim is asked for five candidates, never an unbounded list.
  static const int maxResults = 5;

  final Uri baseUri;
  final Duration timeout;

  /// Minimum spacing between requests; Nominatim's hard limit is 1/second.
  final Duration minInterval;
  final String userAgent;

  final http.Client _client;
  final Future<void> Function(Duration) _wait;
  final DateTime Function() _now;

  DateTime? _lastRequestAt;

  /// Repeat lookups of the same 4-decimal point (about 11 m) reuse the answer
  /// instead of asking again, so dragging the pin back and forth stays cheap.
  final Map<String, GeocodingPlace> _reverseCache = {};

  @override
  Future<GeocodingSearchResult> search(
    String query, {
    String languageCode = 'id',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const GeocodingSearchResult.failed(GeocodingFailure.empty);
    }

    final uri = baseUri.replace(
      path: '/search',
      queryParameters: {
        'q': trimmed,
        'format': 'jsonv2',
        'limit': '$maxResults',
        'accept-language': languageCode,
      },
    );

    try {
      final response = await _request(uri);
      if (response.statusCode != 200) {
        throw _HttpFailure(_failureFor(response.statusCode));
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        throw const _HttpFailure(GeocodingFailure.unavailable);
      }

      final places = <GeocodingPlace>[];
      for (final item in decoded) {
        final place = _placeFrom(item);
        if (place != null) places.add(place);
      }
      if (places.isEmpty) {
        return const GeocodingSearchResult.failed(GeocodingFailure.empty);
      }
      return GeocodingSearchResult.success(
        List<GeocodingPlace>.unmodifiable(places),
      );
    } on _HttpFailure catch (failure) {
      return GeocodingSearchResult.failed(failure.failure);
    } catch (_) {
      return const GeocodingSearchResult.failed(GeocodingFailure.unavailable);
    }
  }

  @override
  Future<GeocodingPlaceResult> reverse({
    required double latitude,
    required double longitude,
    String languageCode = 'id',
  }) async {
    final cacheKey =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    final cached = _reverseCache[cacheKey];
    if (cached != null) return GeocodingPlaceResult.success(cached);

    final uri = baseUri.replace(
      path: '/reverse',
      queryParameters: {
        'lat': '$latitude',
        'lon': '$longitude',
        'format': 'jsonv2',
        'zoom': '14',
        'accept-language': languageCode,
      },
    );

    try {
      final response = await _request(uri);
      if (response.statusCode != 200) {
        throw _HttpFailure(_failureFor(response.statusCode));
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final place = _placeFrom(decoded);
      if (place == null) {
        return const GeocodingPlaceResult.failed(GeocodingFailure.empty);
      }
      _reverseCache[cacheKey] = place;
      return GeocodingPlaceResult.success(place);
    } on _HttpFailure catch (failure) {
      return GeocodingPlaceResult.failed(failure.failure);
    } catch (_) {
      return const GeocodingPlaceResult.failed(GeocodingFailure.unavailable);
    }
  }

  Future<http.Response> _request(Uri uri) async {
    await _throttle();
    _lastRequestAt = _now();

    final headers = <String, String>{'Accept': 'application/json'};
    if (!kIsWeb) headers['User-Agent'] = userAgent;

    try {
      return await _client.get(uri, headers: headers).timeout(timeout);
    } on TimeoutException {
      throw const _HttpFailure(GeocodingFailure.timeout);
    } catch (_) {
      throw const _HttpFailure(GeocodingFailure.unavailable);
    }
  }

  Future<void> _throttle() async {
    final last = _lastRequestAt;
    if (last == null) return;
    final remaining = minInterval - _now().difference(last);
    if (remaining > Duration.zero) await _wait(remaining);
  }

  GeocodingFailure _failureFor(int statusCode) => statusCode == 429
      ? GeocodingFailure.rateLimited
      : GeocodingFailure.unavailable;

  GeocodingPlace? _placeFrom(Object? item) {
    if (item is! Map) return null;
    final name = item['display_name'];
    final latitude = _doubleFrom(item['lat']);
    final longitude = _doubleFrom(item['lon']);
    if (name is! String || name.trim().isEmpty) return null;
    if (latitude == null || longitude == null) return null;
    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;
    return GeocodingPlace(
      displayName: name.trim(),
      latitude: latitude,
      longitude: longitude,
    );
  }

  double? _doubleFrom(Object? value) => switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text),
    _ => null,
  };
}

class _HttpFailure implements Exception {
  const _HttpFailure(this.failure);

  final GeocodingFailure failure;
}
