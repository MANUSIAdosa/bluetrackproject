import 'package:blue_track/features/project/data/project_data_repositories.dart';
import 'package:blue_track/features/project/data/review_repository.dart';
import 'package:blue_track/features/project/domain/data_failure.dart';
import 'package:blue_track/features/project/domain/review.dart';
import 'package:flutter_test/flutter_test.dart';

MockReviewRepository _repo({bool forceError = false}) =>
    MockReviewRepository(latency: Duration.zero, forceError: forceError);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReviewRepository reads', () {
    test('sorts reviews newest first by default', () async {
      final reviews = await _repo().getReviewsByLocation('p01');

      expect(reviews.map((review) => review.id), [
        'rev006',
        'rev005',
        'rev004',
        'rev003',
        'rev002',
        'rev001',
      ]);
    });

    test('sorts by highest and lowest rating with newest tie-breaks', () async {
      final repo = _repo();

      final highest = await repo.getReviewsByLocation(
        'p01',
        sort: ReviewSort.highestRating,
      );
      expect(highest.map((review) => review.id), [
        'rev003',
        'rev001',
        'rev006',
        'rev002',
        'rev004',
        'rev005',
      ]);

      final lowest = await repo.getReviewsByLocation(
        'p01',
        sort: ReviewSort.lowestRating,
      );
      expect(lowest.map((review) => review.id), [
        'rev005',
        'rev004',
        'rev006',
        'rev002',
        'rev003',
        'rev001',
      ]);
    });

    test(
      'summarizes average, count and distribution with one decimal',
      () async {
        final repo = _repo();

        final p01 = await repo.getReviewSummary('p01');
        expect(p01.averageRating.toStringAsFixed(1), '3.8');
        expect(p01.totalReviews, 6);
        expect(p01.ratingDistribution, {1: 0, 2: 1, 3: 1, 4: 2, 5: 2});

        final p03 = await repo.getReviewSummary('p03');
        expect(p03.averageRating, 3.0);
        expect(p03.totalReviews, 5);
        expect(p03.ratingDistribution, {1: 1, 2: 1, 3: 1, 4: 1, 5: 1});

        final p04 = await repo.getReviewSummary('p04');
        expect(p04.averageRating.toStringAsFixed(1), '4.2');
        expect(p04.totalReviews, 5);
      },
    );

    test(
      'a location without reviews returns an empty list and zero summary',
      () async {
        final repo = _repo();

        expect(await repo.getReviewsByLocation('p06'), isEmpty);

        final summary = await repo.getReviewSummary('p06');
        expect(summary.averageRating, 0.0);
        expect(summary.totalReviews, 0);
        expect(summary.ratingDistribution.keys, containsAll([1, 2, 3, 4, 5]));
        expect(summary.ratingDistribution.values, everyElement(0));
      },
    );

    test('distribution always sums to the review count', () async {
      final repo = _repo();

      for (final locationId in ['p01', 'p02', 'p03', 'p04', 'p05', 'p06']) {
        final summary = await repo.getReviewSummary(locationId);
        final distributionTotal = summary.ratingDistribution.values.fold<int>(
          0,
          (sum, count) => sum + count,
        );
        expect(distributionTotal, summary.totalReviews, reason: locationId);
      }
    });

    test('at least three locations expose five or more reviews', () async {
      final repo = _repo();

      var covered = 0;
      for (final locationId in ['p01', 'p02', 'p03', 'p04', 'p05']) {
        final reviews = await repo.getReviewsByLocation(locationId);
        if (reviews.length >= 5) covered++;
      }

      expect(covered, greaterThanOrEqualTo(3));
    });

    test('unknown location throws a typed error', () async {
      final repo = _repo();

      await expectLater(
        repo.getReviewsByLocation('p99'),
        throwsA(isA<LocationNotFoundException>()),
      );
      await expectLater(
        repo.getReviewSummary('p99'),
        throwsA(isA<LocationNotFoundException>()),
      );
    });
  });

  group('ReviewRepository mock controls', () {
    test('forceError makes both calls throw a typed mock error', () async {
      final repo = _repo(forceError: true);

      await expectLater(
        repo.getReviewsByLocation('p01'),
        throwsA(isA<MockRepositoryException>()),
      );
      await expectLater(
        repo.getReviewSummary('p01'),
        throwsA(isA<MockRepositoryException>()),
      );
    });

    test('the feature registry exposes the mock implementation', () {
      expect(ProjectDataRepositories.reviews, isA<MockReviewRepository>());
    });
  });
}
