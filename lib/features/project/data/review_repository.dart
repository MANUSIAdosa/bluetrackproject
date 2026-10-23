import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/data_failure.dart';
import '../domain/location.dart';
import '../domain/review.dart';
import 'mock_repository_support.dart';

/// Data source contract for location reviews (P04 Reviews tab).
///
/// UI code depends on this interface only, so the mock implementation can be
/// replaced by an API client later without rewriting pages. All methods are
/// asynchronous and location ids match the P04 project ids.
abstract interface class ReviewRepository {
  /// Reviews for one location, in the requested [sort] order.
  ///
  /// Returns an empty list when the location exists but has no reviews. Throws
  /// [LocationNotFoundException] when [locationId] is unknown.
  ///
  /// ```dart
  /// final reviews = await repository.getReviewsByLocation(
  ///   'p01',
  ///   sort: ReviewSort.highestRating,
  /// );
  /// ```
  Future<List<Review>> getReviewsByLocation(
    String locationId, {
    ReviewSort sort = ReviewSort.newest,
  });

  /// Average, count and 1–5 distribution for one location.
  ///
  /// [ReviewSummary.averageRating] is rounded to one decimal place. A location
  /// with no reviews returns `0.0`, a zero count, and a distribution with keys
  /// 1–5 all set to zero. Throws [LocationNotFoundException] when
  /// [locationId] is unknown.
  ///
  /// ```dart
  /// final summary = await repository.getReviewSummary('p01');
  /// print(summary.averageRating);
  /// ```
  Future<ReviewSummary> getReviewSummary(String locationId);
}

/// Mock implementation reading `assets/mock/review.json` and
/// `assets/mock/locations.json`.
class MockReviewRepository implements ReviewRepository {
  /// Creates a mock repository.
  ///
  /// [latency] simulates a network call. Leave it null for a random 300–800 ms
  /// delay, or pass [Duration.zero] to disable it — required in tests.
  ///
  /// When [forceError] is true every method throws [MockRepositoryException]
  /// after the simulated delay, so Loading and Error states can be exercised.
  MockReviewRepository({this.latency, this.forceError = false});

  static const _reviewsAsset = 'assets/mock/review.json';
  static const _locationsAsset = 'assets/mock/locations.json';

  /// Simulated call delay; null means a random 300–800 ms delay.
  final Duration? latency;

  /// When true, every method throws [MockRepositoryException].
  final bool forceError;

  List<Review>? _reviews;
  Set<String>? _locationIds;

  Future<List<Review>> _loadReviews() async {
    final cached = _reviews;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_reviewsAsset);
    final decoded = jsonDecode(raw) as List<dynamic>;
    final reviews = decoded
        .map((item) => Review.fromJson(item as Map<String, dynamic>))
        .toList();
    return _reviews = reviews;
  }

  Future<Set<String>> _loadLocationIds() async {
    final cached = _locationIds;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_locationsAsset);
    final decoded = jsonDecode(raw) as List<dynamic>;
    final ids = decoded
        .map(
          (item) => ProjectLocation.fromJson(item as Map<String, dynamic>).id,
        )
        .toSet();
    return _locationIds = ids;
  }

  Future<void> _ensureLocation(String locationId) async {
    final ids = await _loadLocationIds();
    if (!ids.contains(locationId)) {
      throw LocationNotFoundException(locationId);
    }
  }

  @override
  Future<List<Review>> getReviewsByLocation(
    String locationId, {
    ReviewSort sort = ReviewSort.newest,
  }) async {
    await simulateMockCall(latency: latency, forceError: forceError);
    await _ensureLocation(locationId);

    final reviews =
        (await _loadReviews())
            .where((review) => review.locationId == locationId)
            .toList()
          ..sort(_comparator(sort));
    return List<Review>.unmodifiable(reviews);
  }

  @override
  Future<ReviewSummary> getReviewSummary(String locationId) async {
    await simulateMockCall(latency: latency, forceError: forceError);
    await _ensureLocation(locationId);

    final reviews = (await _loadReviews()).where(
      (review) => review.locationId == locationId,
    );
    final distribution = <int, int>{
      for (var rating = 1; rating <= 5; rating++) rating: 0,
    };

    var total = 0;
    var sum = 0;
    for (final review in reviews) {
      distribution[review.rating] = (distribution[review.rating] ?? 0) + 1;
      total++;
      sum += review.rating;
    }

    final average = total == 0 ? 0.0 : (sum / total * 10).round() / 10;
    return ReviewSummary(
      averageRating: average,
      totalReviews: total,
      ratingDistribution: Map<int, int>.unmodifiable(distribution),
    );
  }

  Comparator<Review> _comparator(ReviewSort sort) {
    switch (sort) {
      case ReviewSort.newest:
        return _newestFirst;
      case ReviewSort.highestRating:
        return (a, b) {
          final byRating = b.rating.compareTo(a.rating);
          return byRating != 0 ? byRating : _newestFirst(a, b);
        };
      case ReviewSort.lowestRating:
        return (a, b) {
          final byRating = a.rating.compareTo(b.rating);
          return byRating != 0 ? byRating : _newestFirst(a, b);
        };
    }
  }

  int _newestFirst(Review a, Review b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }
}
