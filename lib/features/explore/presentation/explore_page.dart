import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/filter_chip_row.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/project_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';
import '../../repositories.dart';

/// P03 — Explore (list mode).
///
/// - Search, a single-select category chip row, a saved-projects toggle next to
///   the search field (Hive), interest sorting, loading / empty / error states,
///   notification bell.
/// - One control represents one context: the chip row filters by category, the
///   bookmark button filters the saved collection, and the segmented button
///   switches the view mode.
/// - The list is paged: only [_pageSize] projects at a time, the next page
///   appended when the user scrolls near the bottom.
/// - Map mode is a query-param sibling of this page (deferred: see
///   [explore.mapUnavailable]).
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, this.projectRepository, this.filterRepository});

  /// Test seams — when null the page reads the registry ([Repositories]).
  /// The router keeps constructing `const ExplorePage()`.
  final ProjectRepository? projectRepository;
  final FilterRepository? filterRepository;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  /// Projects per page. The product spec says 10; 4 keeps the paging visible
  /// with the small mock data set.
  static const int _pageSize = 4;

  /// Mock latency of a page request, so the inline placeholder is visible.
  static const Duration _pageLatency = Duration(milliseconds: 300);

  /// Distance from the bottom (logical pixels) that requests the next page.
  static const double _loadMoreThreshold = 200;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Project> _all = const [];
  List<String> _categoryIds = const ['semua'];
  List<String> _interests = const [];

  String _category = 'semua';
  String _query = '';
  bool _loading = true;
  bool _error = false;
  bool _mapMode = false;

  /// The saved collection is a context of its own, not a category: it lives in
  /// [SavedProjectsController], and the bookmark button beside the search field
  /// switches it on and off.
  bool _savedOnly = false;

  /// How many of the filtered projects the list shows (grows by page).
  int _visibleCount = _pageSize;
  bool _loadingMore = false;

  ProjectRepository get _projects =>
      widget.projectRepository ?? Repositories.projects;
  FilterRepository get _filters =>
      widget.filterRepository ?? Repositories.filters;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _resetPaging();
    setState(() {
      _loading = true;
      _error = false;
      _loadingMore = false;
    });
    try {
      final projects = await _projects.getProjects();
      final categories = await _filters.getCategoryIds();
      final interests = await OnboardingState.readInterests();
      if (!mounted) return;
      setState(() {
        _all = projects;
        _categoryIds = categories;
        _interests = interests;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  /// Requests the next page when the list is scrolled close to the bottom.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _loadNextPage();
    }
  }

  /// Appends the next page of already fetched mock projects after a short
  /// delay, so the placeholder below the list behaves like a real request.
  Future<void> _loadNextPage() async {
    if (_loading || _loadingMore) return;
    final total = _visible.length;
    if (_visibleCount >= total) return;
    setState(() => _loadingMore = true);
    await Future<void>.delayed(_pageLatency);
    // A reload (pull to refresh / retry) already reset the paging.
    if (!mounted || _loading) return;
    setState(() {
      _visibleCount = math.min(_visibleCount + _pageSize, total);
      _loadingMore = false;
    });
  }

  /// Back to the first page. The offset also jumps to the top: a shorter
  /// result set would otherwise leave the viewport near the new bottom and
  /// immediately ask for the next page.
  void _resetPaging() {
    _visibleCount = _pageSize;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// Recovery action for an empty search/filter result: clear the query, go back
  /// to the "Semua" category and leave the saved collection, so the list can
  /// recover.
  void _resetFilters() {
    _searchController.clear();
    _resetPaging();
    setState(() {
      _query = '';
      _category = 'semua';
      _savedOnly = false;
    });
  }

  /// Leaves the saved collection without touching the category or the query —
  /// the other filters stay as the user set them.
  void _showAllProjects() {
    _resetPaging();
    setState(() => _savedOnly = false);
  }

  List<Project> get _visible {
    // One context per control, applied in that order: the saved collection,
    // then the category chip, then the search query.
    final saved = SavedProjectsController.instance.ids;
    var list = _all.where((p) {
      final matchesSaved = !_savedOnly || saved.contains(p.id);
      final matchesCategory = _category == 'semua' || p.category == _category;
      final matchesQuery =
          _query.isEmpty ||
          p.title.toLowerCase().contains(_query) ||
          p.orgName.toLowerCase().contains(_query) ||
          p.location.toLowerCase().contains(_query);
      return matchesSaved && matchesCategory && matchesQuery;
    }).toList();

    // Personalized sorting: interest matches first.
    if (_interests.isNotEmpty) {
      list = [...list]
        ..sort((a, b) {
          final aRank = _interests.contains(a.category) ? 0 : 1;
          final bRank = _interests.contains(b.category) ? 0 : 1;
          return aRank.compareTo(bRank);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final savedCount = SavedProjectsController.instance.ids.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('explore.title')),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.tr('explore.searchHint'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _resetPaging();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (value) {
                      _resetPaging();
                      setState(() => _query = value.trim().toLowerCase());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _SavedFilterButton(
                  key: const ValueKey('explore.savedFilter'),
                  active: _savedOnly,
                  savedCount: savedCount,
                  onChanged: (active) {
                    _resetPaging();
                    setState(() => _savedOnly = active);
                  },
                ),
              ],
            ),
          ),
          // Categories only: the saved collection has its own control above.
          FilterChipRow(
            options: [
              for (final id in _categoryIds)
                ChipOption(id: id, label: context.tr('cat.$id')),
            ],
            selectedId: _category,
            onSelected: (id) {
              _resetPaging();
              setState(() => _category = id);
            },
          ),
          const SizedBox(height: 8),
          _ListMapToggle(
            mapMode: _mapMode,
            onChanged: (map) => setState(() => _mapMode = map),
          ),
          const SizedBox(height: 4),
          Expanded(child: _buildBody(visible)),
        ],
      ),
    );
  }

  Widget _buildBody(List<Project> visible) {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [SkeletonCard(), SizedBox(height: 16), SkeletonCard()],
      );
    }
    if (_error) {
      return ErrorState(onRetry: _load);
    }
    if (_mapMode) {
      return EmptyState(
        icon: Icons.map_outlined,
        message: context.tr('explore.mapUnavailable'),
      );
    }
    if (visible.isEmpty) {
      // Two different failures behind the same bookmark toggle: nothing has
      // been saved yet, or the saved projects do not match the other filters.
      if (_savedOnly) {
        final nothingSaved = SavedProjectsController.instance.ids.isEmpty;
        return EmptyState(
          icon: nothingSaved ? Icons.bookmark_outline : Icons.search_off,
          message: context.tr(
            nothingSaved
                ? 'explore.emptySaved.title'
                : 'explore.emptySavedFiltered.title',
          ),
          actionLabel: context.tr(
            nothingSaved ? 'explore.viewAll' : 'explore.resetFilter',
          ),
          onAction: nothingSaved ? _showAllProjects : _resetFilters,
        );
      }
      return EmptyState(
        icon: Icons.search_off,
        message: context.tr('explore.empty.title'),
        actionLabel: context.tr('explore.resetFilter'),
        onAction: _resetFilters,
      );
    }

    // The saved collection is already a personal selection, so the interest
    // rail stays out of the way while it is on.
    final forYou = (_savedOnly || _interests.isEmpty)
        ? const <Project>[]
        : visible
              .where((p) => _interests.contains(p.category))
              .take(5)
              .toList();
    final page = visible.take(_visibleCount).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (forYou.isNotEmpty && _category == 'semua' && _query.isEmpty) ...[
            _sectionHeader(context.tr('explore.forYou')),
            _ForYouRail(
              key: const ValueKey('explore.forYouRail'),
              projects: forYou,
              onSavedChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
            _sectionHeader(context.tr('explore.projects')),
          ],
          for (final project in page) ...[
            ProjectCard(
              project: project,
              onSavedChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
          ],
          // Small placeholder while the next page is appended.
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Skeleton(height: 72, radius: 12),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
    ),
  );
}

/// Horizontal "Untuk minatmu" rail.
///
/// Its height is measured from the cards themselves ([IntrinsicHeight]) rather
/// than pinned to a constant, so it can never be shorter than a card: a
/// one-line or two-line title, a longer location or a large text scale are all
/// fine. Cards are compact — no donate CTA — and stretched to one height.
class _ForYouRail extends StatelessWidget {
  const _ForYouRail({
    super.key,
    required this.projects,
    required this.onSavedChanged,
  });

  final List<Project> projects;
  final VoidCallback onSavedChanged;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < projects.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: ProjectCard(
                  project: projects[i],
                  showDonateButton: false,
                  onSavedChanged: onSavedChanged,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListMapToggle extends StatelessWidget {
  const _ListMapToggle({required this.mapMode, required this.onChanged});

  final bool mapMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<bool>(
        segments: [
          ButtonSegment(
            value: false,
            label: Text(context.tr('explore.viewList')),
            icon: const Icon(Icons.view_list_outlined),
          ),
          ButtonSegment(
            value: true,
            label: Text(context.tr('explore.viewMap')),
            icon: const Icon(Icons.map_outlined),
          ),
        ],
        selected: {mapMode},
        onSelectionChanged: (set) => onChanged(set.first),
        showSelectedIcon: false,
      ),
    );
  }
}

/// Bookmark toggle for the saved-projects collection, beside the search field.
///
/// The collection is a context of its own, so it is a button and not a chip in
/// the category row. While it is on, the chip row and the search field keep
/// narrowing *within* the saved projects.
class _SavedFilterButton extends StatelessWidget {
  const _SavedFilterButton({
    super.key,
    required this.active,
    required this.savedCount,
    required this.onChanged,
  });

  final bool active;

  /// Number of saved projects, badged on the button when there is any.
  final int savedCount;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      // Names the action, so it reads correctly in either state.
      tooltip: context.tr(
        active ? 'explore.savedFilter.off' : 'explore.savedFilter.on',
      ),
      icon: Icon(active ? Icons.bookmark : Icons.bookmark_outline),
      color: active ? AppColors.ocean : AppColors.textSecondary,
      // Material's minimum touch target.
      style: IconButton.styleFrom(minimumSize: const Size.square(48)),
      onPressed: () => onChanged(!active),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? AppColors.ocean.withValues(alpha: 0.10)
            : Colors.transparent,
        border: Border.all(color: active ? AppColors.ocean : AppColors.border),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: savedCount > 0
          ? Badge(label: Text('$savedCount'), child: button)
          : button,
    );
  }
}
