import 'dart:convert';
import 'dart:io';

import 'package:blue_track/features/project/data/review_repository.dart';
import 'package:blue_track/features/project/domain/review.dart';

/// Parses the bundled review mock from disk once.
///
/// Widget tests cannot reliably await `rootBundle` after the first test in the
/// same file on Windows, so read the same JSON synchronously instead.
List<Review>? _reviewsCache;

List<Review> mockReviews() {
  final cached = _reviewsCache;
  if (cached != null) return cached;

  final raw = File('assets/mock/review.json').readAsStringSync();
  final decoded = jsonDecode(raw) as List<dynamic>;
  return _reviewsCache = decoded
      .map((item) => Review.fromJson(item as Map<String, dynamic>))
      .toList(growable: false);
}

/// Builds a [Review] with sensible defaults so tests only state what matters.
Review buildReview({
  String id = 'r01',
  String locationId = 'p01',
  String authorId = 'u-test',
  String authorName = 'Pengulas Uji',
  int rating = 5,
  String comment = 'Komentar ulasan untuk pengujian.',
  DateTime? createdAt,
}) {
  return Review(
    id: id,
    locationId: locationId,
    authorId: authorId,
    authorName: authorName,
    rating: rating,
    comment: comment,
    createdAt: (createdAt ?? DateTime.utc(2026, 10, 1)).toUtc(),
  );
}

/// In-memory [ReviewRepository] with the same sorting and summary rules as
/// [MockReviewRepository], plus call counters for reload assertions.
class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository({List<Review>? reviews, this.shouldFail = false})
    : _reviews = List<Review>.of(reviews ?? mockReviews());

  final List<Review> _reviews;

  /// When true every call throws, so the error state can be exercised.
  bool shouldFail;

  int reviewCallCount = 0;
  int summaryCallCount = 0;

  List<Review> _forLocation(String locationId) => _reviews
      .where((review) => review.locationId == locationId)
      .toList(growable: false);

  @override
  Future<List<Review>> getReviewsByLocation(
    String locationId, {
    ReviewSort sort = ReviewSort.newest,
  }) async {
    reviewCallCount++;
    if (shouldFail) throw Exception('Simulated review repository failure');
    final reviews = _forLocation(locationId)..sort(_comparator(sort));
    return List<Review>.unmodifiable(reviews);
  }

  @override
  Future<ReviewSummary> getReviewSummary(String locationId) async {
    summaryCallCount++;
    if (shouldFail) throw Exception('Simulated review repository failure');
    final reviews = _forLocation(locationId);
    final distribution = <int, int>{
      for (var rating = 1; rating <= 5; rating++) rating: 0,
    };
    var sum = 0;
    for (final review in reviews) {
      distribution[review.rating] = (distribution[review.rating] ?? 0) + 1;
      sum += review.rating;
    }
    final average = reviews.isEmpty
        ? 0.0
        : (sum / reviews.length * 10).round() / 10;
    return ReviewSummary(
      averageRating: average,
      totalReviews: reviews.length,
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
