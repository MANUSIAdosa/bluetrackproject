import 'dart:async';

import 'package:blue_track/features/project/data/review_repository.dart';
import 'package:blue_track/features/project/domain/review.dart';
import 'package:blue_track/features/project/presentation/project_detail_page.dart';
import 'package:blue_track/features/project/presentation/widgets/p04_reviews_tab.dart';
import 'package:blue_track/shared/widgets/empty_state.dart';
import 'package:blue_track/shared/widgets/error_state.dart';
import 'package:blue_track/shared/widgets/filter_chip_row.dart';
import 'package:blue_track/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/report_fixtures.dart';
import 'support/review_fixtures.dart';
import 'support/test_harness.dart';

/// Holds both repository calls until [gate] completes, so the loading state is
/// observable without relying on mock latency.
class _GatedReviewRepository implements ReviewRepository {
  _GatedReviewRepository(this._delegate, this.gate);

  final ReviewRepository _delegate;
  final Future<void> gate;

  Future<T> _wait<T>(Future<T> Function() call) async {
    await gate;
    return call();
  }

  @override
  Future<List<Review>> getReviewsByLocation(
    String locationId, {
    ReviewSort sort = ReviewSort.newest,
  }) => _wait(() => _delegate.getReviewsByLocation(locationId, sort: sort));

  @override
  Future<ReviewSummary> getReviewSummary(String locationId) =>
      _wait(() => _delegate.getReviewSummary(locationId));
}

/// Two-tab harness mirroring P04's TabBarView so keeping the review list alive
/// across tab switches can be asserted.
class _TabsHost extends StatelessWidget {
  const _TabsHost({required this.repository});

  final ReviewRepository repository;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Lain'),
              Tab(text: 'Ulasan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const Center(child: Text('Halaman lain')),
            P04ReviewsTab(projectId: 'p01', repository: repository),
          ],
        ),
      ),
    );
  }
}

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpReviews(
  WidgetTester tester, {
  String projectId = 'p01',
  ReviewRepository? repository,
  Locale locale = const Locale('id'),
  Size size = const Size(500, 1200),
  bool settle = true,
}) async {
  _setScreen(tester, size);
  await tester.pumpWidget(
    wrapPage(
      P04ReviewsTab(
        projectId: projectId,
        repository: repository ?? InMemoryReviewRepository(),
      ),
      locale: locale,
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Finder _listFinder() => find.byKey(const PageStorageKey('p04-reviews-scroll'));

Finder _scrollable() =>
    find.descendant(of: _listFinder(), matching: find.byType(Scrollable)).first;

/// IDs sorted by the vertical position of their review card.
List<String> _reviewOrder(WidgetTester tester, List<String> ids) {
  final positions = {
    for (final id in ids)
      id: tester.getTopLeft(find.byKey(ValueKey('p04-review-$id'))).dy,
  };
  final sorted = List<String>.of(ids)
    ..sort((a, b) => positions[a]!.compareTo(positions[b]!));
  return sorted;
}

bool _chipSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

List<Review> _sortingFixture() => [
  buildReview(
    id: 'r1',
    rating: 5,
    comment: 'Ulasan pertama.',
    createdAt: DateTime.utc(2026, 1, 1),
  ),
  buildReview(
    id: 'r2',
    rating: 5,
    comment: 'Ulasan kedua.',
    createdAt: DateTime.utc(2026, 2, 1),
  ),
  buildReview(
    id: 'r3',
    rating: 3,
    comment: 'Ulasan ketiga.',
    createdAt: DateTime.utc(2026, 3, 1),
  ),
  buildReview(
    id: 'r4',
    rating: 4,
    comment: 'Ulasan keempat.',
    createdAt: DateTime.utc(2026, 4, 1),
  ),
];

List<Review> _pagedFixture() => [
  for (var index = 1; index <= 12; index++)
    buildReview(
      id: 'r${index.toString().padLeft(2, '0')}',
      comment: 'Ulasan halaman $index.',
      createdAt: DateTime.utc(2026, 12, 31).subtract(Duration(days: index)),
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P04 reviews tab', () {
    testWidgets('shows Skeleton while loading, then the summary', (
      tester,
    ) async {
      final gate = Completer<void>();
      await _pumpReviews(
        tester,
        repository: _GatedReviewRepository(
          InMemoryReviewRepository(),
          gate.future,
        ),
        settle: false,
      );
      await tester.pump();

      expect(find.byType(Skeleton), findsWidgets);
      expect(find.byKey(const ValueKey('p04-review-average')), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(Skeleton), findsNothing);
      expect(find.byKey(const ValueKey('p04-review-average')), findsOneWidget);
    });

    testWidgets('summary formats the average per locale and lists a complete '
        'distribution', (tester) async {
      await _pumpReviews(tester, projectId: 'p01');

      expect(find.byKey(const ValueKey('p04-reviews-summary')), findsOneWidget);
      expect(find.text('Ringkasan ulasan'), findsOneWidget);
      expect(find.text('Rata-rata'), findsOneWidget);
      expect(find.text('3,8'), findsOneWidget);
      expect(find.text('6 ulasan'), findsOneWidget);

      const expectedCounts = {5: '2', 4: '2', 3: '1', 2: '1', 1: '0'};
      var distributionTotal = 0;
      for (final entry in expectedCounts.entries) {
        final row = find.byKey(
          ValueKey('p04-review-distribution-${entry.key}'),
        );
        expect(row, findsOneWidget);
        expect(
          find.descendant(of: row, matching: find.text(entry.value)),
          findsOneWidget,
          reason: 'rating ${entry.key}',
        );
        distributionTotal += int.parse(entry.value);
      }
      expect(distributionTotal, 6);
    });

    testWidgets('English summary uses a dot separator and English labels', (
      tester,
    ) async {
      await _pumpReviews(tester, projectId: 'p01', locale: const Locale('en'));

      expect(find.text('Review summary'), findsOneWidget);
      expect(find.text('Average'), findsOneWidget);
      expect(find.text('3.8'), findsOneWidget);
      expect(find.text('6 reviews'), findsOneWidget);
      expect(find.text('Terbaru'), findsNothing);
      expect(find.text('Newest'), findsOneWidget);
    });

    testWidgets('sorting respects rating order and newest tie-breaks without '
        'reloading', (tester) async {
      final repository = InMemoryReviewRepository(reviews: _sortingFixture());
      await _pumpReviews(
        tester,
        repository: repository,
        size: const Size(700, 1400),
      );

      const ids = ['r1', 'r2', 'r3', 'r4'];
      expect(_reviewOrder(tester, ids), ['r4', 'r3', 'r2', 'r1']);
      expect(_chipSelected(tester, 'Terbaru'), isTrue);

      await tester.tap(find.text('Rating tertinggi'));
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, 'Rating tertinggi'), isTrue);
      expect(_reviewOrder(tester, ids), ['r2', 'r1', 'r4', 'r3']);

      await tester.tap(find.text('Rating terendah'));
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, 'Rating terendah'), isTrue);
      expect(_reviewOrder(tester, ids), ['r3', 'r4', 'r2', 'r1']);
      expect(repository.reviewCallCount, 1);
      expect(repository.summaryCallCount, 1);
      expect(find.byType(Skeleton), findsNothing);
    });

    testWidgets('Selengkapnya appears only for a truly truncated comment and '
        'expands it', (tester) async {
      final longName = List.filled(10, 'Nama').join();
      final longComment = List.filled(
        10,
        'Komentar panjang untuk pengujian tampilan ulasan.',
      ).join(' ');
      final shortComment = 'Ulasan singkat.';
      final repository = InMemoryReviewRepository(
        reviews: [
          buildReview(
            id: 'short',
            authorName: 'Nama Pendek',
            rating: 5,
            comment: shortComment,
            createdAt: DateTime.utc(2026, 4, 1),
          ),
          buildReview(
            id: 'long',
            authorName: longName,
            rating: 4,
            comment: longComment,
            createdAt: DateTime.utc(2026, 3, 1),
          ),
        ],
      );

      await _pumpReviews(
        tester,
        repository: repository,
        size: const Size(320, 1000),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(longName), findsOneWidget);
      expect(
        find.byKey(const ValueKey('p04-review-toggle-short')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('p04-review-toggle-long')), findsOne);
      expect(find.text('Selengkapnya'), findsOneWidget);

      final collapsed = tester.widget<Text>(find.text(longComment));
      expect(collapsed.maxLines, 3);

      await tester.ensureVisible(
        find.byKey(const ValueKey('p04-review-toggle-long')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('p04-review-toggle-long')));
      await tester.pumpAndSettle();

      final expanded = tester.widget<Text>(find.text(longComment));
      expect(expanded.maxLines, isNull);
      expect(find.text('Sembunyikan'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('p04-review-toggle-long')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('p04-review-toggle-long')));
      await tester.pumpAndSettle();

      final recollapsed = tester.widget<Text>(find.text(longComment));
      expect(recollapsed.maxLines, 3);
      expect(find.text('Selengkapnya'), findsOneWidget);
    });

    testWidgets('caps the list at 10 and loads more on request', (
      tester,
    ) async {
      await _pumpReviews(
        tester,
        repository: InMemoryReviewRepository(reviews: _pagedFixture()),
        size: const Size(500, 1000),
      );

      expect(find.byKey(const ValueKey('p04-review-r01')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('p04-reviews-load-more')),
        400,
        scrollable: _scrollable(),
      );
      await tester.tap(find.byKey(const ValueKey('p04-reviews-load-more')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('p04-reviews-load-more')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('p04-review-r12')),
        400,
        scrollable: _scrollable(),
      );
      expect(find.byKey(const ValueKey('p04-review-r12')), findsOneWidget);
    });

    testWidgets('locations without reviews show the empty state', (
      tester,
    ) async {
      await _pumpReviews(tester, projectId: 'p06');

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Belum ada ulasan'), findsOneWidget);
      expect(find.byType(FilterChipRow), findsNothing);
      expect(find.byKey(const ValueKey('p04-review-average')), findsNothing);
    });

    testWidgets('failure shows ErrorState and retries in place', (
      tester,
    ) async {
      final repository = InMemoryReviewRepository()..shouldFail = true;
      await _pumpReviews(tester, repository: repository);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Gagal memuat ulasan.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);

      repository.shouldFail = false;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('3,8'), findsOneWidget);
    });

    testWidgets('keeps the review scroll position after switching tabs', (
      tester,
    ) async {
      _setScreen(tester, const Size(500, 900));
      await tester.pumpWidget(
        wrapPage(
          _TabsHost(
            repository: InMemoryReviewRepository(reviews: _pagedFixture()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Ulasan'));
      await tester.pumpAndSettle();

      await tester.drag(_listFinder(), const Offset(0, -500));
      await tester.pumpAndSettle();
      final before = tester
          .state<ScrollableState>(_scrollable())
          .position
          .pixels;
      expect(before, greaterThan(0));

      await tester.tap(find.widgetWithText(Tab, 'Lain'));
      await tester.pumpAndSettle();
      expect(find.text('Halaman lain'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Ulasan'));
      await tester.pumpAndSettle();

      final after = tester
          .state<ScrollableState>(_scrollable())
          .position
          .pixels;
      expect(after, closeTo(before, 0.5));
    });

    testWidgets(
      'detail page wires the reviews tab to the injected repository',
      (tester) async {
        _setScreen(tester, const Size(420, 950));
        await tester.pumpWidget(
          wrapPage(
            ProjectDetailPage(
              projectId: 'p01',
              projectRepository: FakeProjectRepository([
                buildProject(location: 'Pantai Sukamade, Jawa Timur'),
              ]),
              reportRepository: InMemoryReportRepository(),
              reviewRepository: InMemoryReviewRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.widgetWithText(Tab, 'Ulasan'));
        await tester.tap(find.widgetWithText(Tab, 'Ulasan'));
        await tester.pumpAndSettle();

        expect(find.text('Ringkasan ulasan'), findsOneWidget);
        expect(find.text('3,8'), findsOneWidget);
        expect(find.text('6 ulasan'), findsOneWidget);
      },
    );
  });
}
