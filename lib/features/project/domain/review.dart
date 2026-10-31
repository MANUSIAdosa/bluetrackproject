/// Review (ulasan) domain model for the P04 Reviews tab.
///
/// The mock source lives in `assets/mock/review.json`.
class Review {
  const Review({
    required this.id,
    required this.locationId,
    required this.authorId,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  /// Unique review id, for example `rev001`.
  final String id;

  /// Id of the `ProjectLocation` being reviewed.
  final String locationId;

  /// Opaque reviewer id. No email address or phone number is stored.
  final String authorId;

  /// Public display name shown in the UI.
  final String authorName;

  /// Rating from 1 to 5.
  final int rating;

  /// Review text shown on P04.
  final String comment;

  /// Review time in UTC. Serialized as ISO 8601 in the mock JSON.
  final DateTime createdAt;

  /// Parses one review object from `assets/mock/review.json`.
  ///
  /// Throws a [FormatException] when a required key is missing, has the wrong
  /// type, or when [rating] is outside 1–5.
  factory Review.fromJson(Map<String, dynamic> json) {
    final rating = json['rating'] as int;
    if (rating < 1 || rating > 5) {
      throw FormatException('Review rating must be between 1 and 5: $rating');
    }
    return Review(
      id: json['id'] as String,
      locationId: json['locationId'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String,
      rating: rating,
      comment: json['comment'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    );
  }

  /// Serializes this review back to the mock JSON shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'locationId': locationId,
    'authorId': authorId,
    'authorName': authorName,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// Ordering options for `ReviewRepository.getReviewsByLocation`.
enum ReviewSort {
  /// Newest review first.
  newest,

  /// Highest rating first, newest first for equal ratings.
  highestRating,

  /// Lowest rating first, newest first for equal ratings.
  lowestRating,
}

/// Aggregate rating information for one location.
class ReviewSummary {
  const ReviewSummary({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  /// Average rating rounded to one decimal place, or `0.0` when there are no
  /// reviews.
  final double averageRating;

  /// Number of reviews for the location.
  final int totalReviews;

  /// Number of reviews per rating. Keys 1–5 are always present, even when the
  /// count is zero.
  final Map<int, int> ratingDistribution;

  /// Number of reviews with [rating], or zero when the key is absent.
  int countFor(int rating) => ratingDistribution[rating] ?? 0;
}
