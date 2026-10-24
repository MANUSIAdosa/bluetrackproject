import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/filter_chip_row.dart';
import '../../../../shared/widgets/progress_bar.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../data/review_repository.dart';
import '../../domain/review.dart';
import '../p04_format.dart';

/// Reviews tab of P04.
///
/// Read-only: it shows the rating summary, a sort selector and review cards.
/// Summary and reviews are fetched once; changing the sort only reorders the
/// in-memory list, so the page (and its scroll position) never reloads.
class P04ReviewsTab extends StatefulWidget {
  const P04ReviewsTab({
    super.key,
    required this.projectId,
    required this.repository,
  });

  /// Location/project id shared with the review mock data.
  final String projectId;

  final ReviewRepository repository;

  @override
  State<P04ReviewsTab> createState() => _P04ReviewsTabState();
}

class _P04ReviewsTabState extends State<P04ReviewsTab>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 10;

  ReviewSummary? _summary;
  List<Review> _reviews = const [];
  ReviewSort _sort = ReviewSort.newest;
  bool _loading = true;
  bool _error = false;
  int _visibleCount = _pageSize;
  int _requestId = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant P04ReviewsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = false;
      _visibleCount = _pageSize;
    });

    try {
      final repository = widget.repository;
      final projectId = widget.projectId;
      // Always fetch the default (newest) order once; the selected sort is
      // applied locally so switching chips cannot trigger a reload.
      final (summary, reviews) = await (
        repository.getReviewSummary(projectId),
        repository.getReviewsByLocation(projectId),
      ).wait;
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _summary = summary;
        _reviews = reviews;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _selectSort(String id) {
    final next = ReviewSort.values.firstWhere(
      (sort) => sort.name == id,
      orElse: () => _sort,
    );
    if (next == _sort) return;
    setState(() {
      _sort = next;
      _visibleCount = _pageSize;
    });
  }

  void _showMore() {
    setState(() => _visibleCount += _pageSize);
  }

  /// Same ordering as [MockReviewRepository]: rating ties use the newest
  /// review first, with the id as the final deterministic tie-break.
  List<Review> get _sortedReviews {
    final sorted = List<Review>.of(_reviews);
    sorted.sort((a, b) {
      switch (_sort) {
        case ReviewSort.newest:
          return _newestFirst(a, b);
        case ReviewSort.highestRating:
          final byRating = b.rating.compareTo(a.rating);
          return byRating != 0 ? byRating : _newestFirst(a, b);
        case ReviewSort.lowestRating:
          final byRating = a.rating.compareTo(b.rating);
          return byRating != 0 ? byRating : _newestFirst(a, b);
      }
    });
    return sorted;
  }

  int _newestFirst(Review a, Review b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const _ReviewsSkeleton();
    if (_error) {
      return Center(
        child: ErrorState(
          message: context.tr('p04_reviews_error'),
          onRetry: _load,
        ),
      );
    }

    final summary = _summary;
    if (summary == null || summary.totalReviews == 0) {
      return Center(
        child: EmptyState(
          icon: Icons.rate_review_outlined,
          message: context.tr('p04_reviews_empty'),
        ),
      );
    }

    final lang = Localizations.localeOf(context).languageCode;
    final sorted = _sortedReviews;
    final visible = sorted.take(_visibleCount).toList();
    final hasMore = sorted.length > _visibleCount;
    final options = [
      ChipOption(
        id: ReviewSort.newest.name,
        label: context.tr('p04_reviews_sort_newest'),
      ),
      ChipOption(
        id: ReviewSort.highestRating.name,
        label: context.tr('p04_reviews_sort_highest'),
      ),
      ChipOption(
        id: ReviewSort.lowestRating.name,
        label: context.tr('p04_reviews_sort_lowest'),
      ),
    ];

    return ListView(
      key: const PageStorageKey('p04-reviews-scroll'),
      primary: false,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.padding,
            8,
            AppDimens.padding,
            0,
          ),
          child: _SummaryCard(summary: summary, lang: lang),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.padding,
            12,
            AppDimens.padding,
            4,
          ),
          child: Text(
            context.tr('p04_reviews_sort_label'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        FilterChipRow(
          options: options,
          selectedId: _sort.name,
          onSelected: _selectSort,
        ),
        const SizedBox(height: 8),
        for (final review in visible)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.padding,
              0,
              AppDimens.padding,
              AppDimens.gap,
            ),
            child: _ReviewCard(review: review, lang: lang),
          ),
        if (hasMore)
          Center(
            child: OutlinedButton.icon(
              key: const ValueKey('p04-reviews-load-more'),
              onPressed: _showMore,
              icon: const Icon(Icons.expand_more),
              label: Text(context.tr('p04_reviews_load_more')),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.lang});

  final ReviewSummary summary;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('p04-reviews-summary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('p04_reviews_summary_title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppDimens.gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 96,
                  child: Column(
                    children: [
                      Text(
                        context.tr('p04_reviews_average'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        P04Format.rating(summary.averageRating, lang),
                        key: const ValueKey('p04-review-average'),
                        style: const TextStyle(
                          fontSize: 38,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: AppColors.oceanDeep,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _Stars(rating: summary.averageRating, size: 16),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                          summary.totalReviews == 1
                              ? 'p04_reviews_count_one'
                              : 'p04_reviews_count',
                          {'n': P04Format.integer(summary.totalReviews, lang)},
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.gap),
                Expanded(
                  child: Column(
                    children: [
                      for (var rating = 5; rating >= 1; rating--)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: _DistributionRow(
                            key: ValueKey('p04-review-distribution-$rating'),
                            rating: rating,
                            count: summary.countFor(rating),
                            total: summary.totalReviews,
                            lang: lang,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    super.key,
    required this.rating,
    required this.count,
    required this.total,
    required this.lang,
  });

  final int rating;
  final int count;
  final int total;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 10,
          child: Text(
            P04Format.integer(rating, lang),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 2),
        const Icon(Icons.star_rounded, size: 12, color: AppColors.warning),
        const SizedBox(width: 6),
        Expanded(
          child: ProgressBar(value: total == 0 ? 0 : count / total, height: 6),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 24,
          child: Text(
            P04Format.integer(count, lang),
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.lang});

  final Review review;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('p04-review-${review.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.ocean.withValues(alpha: 0.12),
                  child: Text(
                    _initials(review.authorName),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ocean,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        P04Format.date(review.createdAt.toLocal(), lang),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _Stars(rating: review.rating.toDouble(), size: 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ExpandableComment(reviewId: review.id, text: review.comment),
          ],
        ),
      ),
    );
  }

  /// One or two uppercase initials, safe for very long single-word names.
  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return String.fromCharCodes(words.first.runes.take(2)).toUpperCase();
    }
    return '${String.fromCharCode(words[0].runes.first)}'
            '${String.fromCharCode(words[1].runes.first)}'
        .toUpperCase();
  }
}

/// Five built-in star icons; the summary uses halves for fractional averages.
class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.size});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 5; index++)
          Icon(_iconFor(index), size: size, color: AppColors.warning),
      ],
    );
  }

  IconData _iconFor(int index) {
    final remaining = rating - index;
    if (remaining >= 0.75) return Icons.star_rounded;
    if (remaining >= 0.25) return Icons.star_half_rounded;
    return Icons.star_outline_rounded;
  }
}

/// Collapses a comment to three rendered lines.
///
/// Truncation is detected with a [TextPainter] at the real available width and
/// text scale, so "Selengkapnya" never appears for a comment that fits — even
/// if it is long in characters.
class _ExpandableComment extends StatefulWidget {
  const _ExpandableComment({required this.reviewId, required this.text});

  final String reviewId;
  final String text;

  @override
  State<_ExpandableComment> createState() => _ExpandableCommentState();
}

class _ExpandableCommentState extends State<_ExpandableComment> {
  static const _maxLines = 3;
  static const _style = TextStyle(
    fontSize: 13,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: _style),
          maxLines: _maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final isTruncated = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : _maxLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: _style,
            ),
            if (isTruncated)
              TextButton(
                key: ValueKey('p04-review-toggle-${widget.reviewId}'),
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  context.tr(
                    _expanded
                        ? 'p04_reviews_read_less'
                        : 'p04_reviews_read_more',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      primary: false,
      padding: const EdgeInsets.all(AppDimens.padding),
      children: const [
        Skeleton(height: 190, radius: 16),
        SizedBox(height: 16),
        Skeleton(width: 72, height: 18),
        SizedBox(height: 8),
        Skeleton(height: 40, radius: 20),
        SizedBox(height: 16),
        Skeleton(height: 124, radius: 16),
        SizedBox(height: 12),
        Skeleton(height: 124, radius: 16),
        SizedBox(height: 12),
        Skeleton(height: 124, radius: 16),
      ],
    );
  }
}
