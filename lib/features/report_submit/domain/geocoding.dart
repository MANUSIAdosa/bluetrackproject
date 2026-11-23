/// Results of looking a place up through a geocoding service.
///
/// The location step treats the pin and its coordinates as the authoritative
/// location; these values only add a human-readable name for the reporter.
class GeocodingPlace {
  const GeocodingPlace({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  /// Full name returned by the provider, for example
  /// `Pantai Sukamade, Banyuwangi`.
  final String displayName;
  final double latitude;
  final double longitude;
}

/// Why a geocoding request produced no place.
///
/// `offline` is not here: the location step checks connectivity before it
/// calls the service, so the service only reports outcomes of a real request.
enum GeocodingFailure {
  /// No answer before the configured timeout.
  timeout,

  /// The provider asked us to slow down (HTTP 429).
  rateLimited,

  /// Any other transport or payload failure.
  unavailable,

  /// The provider answered but knew no such place.
  empty,
}

/// Forward search: a query turned into up to five candidate places.
class GeocodingSearchResult {
  const GeocodingSearchResult.success(this.places) : failure = null;

  const GeocodingSearchResult.failed(this.failure) : places = const [];

  final List<GeocodingPlace> places;
  final GeocodingFailure? failure;

  bool get hasPlaces => places.isNotEmpty;
}

/// Reverse lookup: coordinates turned into the name of that area.
class GeocodingPlaceResult {
  const GeocodingPlaceResult.success(this.place) : failure = null;

  const GeocodingPlaceResult.failed(this.failure) : place = null;

  final GeocodingPlace? place;
  final GeocodingFailure? failure;

  bool get hasPlace => place != null;
}
