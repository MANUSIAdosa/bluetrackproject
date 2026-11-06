import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show TileProvider;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/project_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../repositories.dart';
import '../data/explore_map_repository.dart';
import '../data/project_repository.dart';
import '../data/saved_project_store.dart';
import '../domain/explore_map_data.dart';
import '../domain/interest_categories.dart';
import '../domain/project.dart';
import 'widgets/category_picker.dart';
import 'widgets/explore_header.dart';
import 'widgets/explore_list_widgets.dart';
import 'widgets/explore_map.dart';
import 'widgets/filter_sheet.dart';

/// P03 — Explore (P03 map + list).
///
/// - Gradient header with search and the filter action; the notification bell
///   lives in that header.
/// - One control per context: the scope switch separates Jelajahi from the
///   saved collection, the icon rail selects a category, the filter sheet owns
///   distance and condition, and the header toggles between the list and the
///   map.
/// - Active filters are summarised as labelled tokens, so the user can see and
///   remove each dimension without opening the sheet.
/// - The list is paged: only [_pageSize] projects at a time, the next page
///   appended when the user scrolls near the bottom.
/// - The filter sheet and the list/map share one filtered result set, so
///   switching never resets a filter.
/// - Offline: the saved snapshots in [SavedProjectStore] replace the repository,
///   and the shell's banner (P00) explains why the list is short.
class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    this.projectRepository,
    this.filterRepository,
    this.mapRepository,
    this.mapTileProvider,
  });

  /// Test seams — when null the page reads the registry ([Repositories]).
  /// The router keeps constructing `const ExplorePage()`.
  final ProjectRepository? projectRepository;
  final FilterRepository? filterRepository;
  final ExploreMapRepository? mapRepository;

  /// Test seam: the map uses OpenStreetMap tiles in the app and a fake provider
  /// in widget tests.
  final TileProvider? mapTileProvider;

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
  ExploreMapData? _mapData;
  bool _mapLoading = false;
  bool _mapError = false;

  /// In-flight map-data read, shared by the map and the filter sheet.
  Future<void>? _mapLoadFuture;

  String _category = 'semua';
  String _query = '';
  bool _loading = true;
  bool _error = false;
  bool _mapMode = false;

  /// Conservation-area layer of the map, off until the user asks for it.
  bool _conservationLayer = false;

  /// Filter groups owned by the filter sheet.
  DistanceBand _distance = DistanceBand.semua;
  ProjectCondition? _condition;

  /// The saved collection is a context of its own, not a category: it lives in
  /// [SavedProjectsController], and the scope switch at the top of the page
  /// moves between Jelajahi and Tersimpan.
  bool _savedScope = false;

  /// How many of the filtered projects the list shows (grows by page).
  int _visibleCount = _pageSize;
  bool _loadingMore = false;

  ProjectRepository get _projects =>
      widget.projectRepository ?? Repositories.projects;
  FilterRepository get _filters =>
      widget.filterRepository ?? Repositories.filters;
  ExploreMapRepository get _maps =>
      widget.mapRepository ?? const MockExploreMapRepository();

  bool get _offline => OfflineController.instance.offline;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    OfflineController.instance.addListener(_onOfflineChanged);
    SavedProjectsController.instance.addListener(_onSavedProjectsChanged);
    OnboardingState.interests.addListener(_onInterestsChanged);
    _load();
  }

  @override
  void dispose() {
    OfflineController.instance.removeListener(_onOfflineChanged);
    SavedProjectsController.instance.removeListener(_onSavedProjectsChanged);
    OnboardingState.interests.removeListener(_onInterestsChanged);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Saving from a card, the map sheet or Project Detail changes the saved
  /// scope count and the bookmark icons, so the page has to rebuild.
  void _onSavedProjectsChanged() {
    if (mounted) setState(() {});
  }

  /// The offline switch changes *where* the projects come from, so the list has
  /// to be rebuilt from the other source.
  void _onOfflineChanged() {
    if (!mounted) return;
    _load();
  }

  void _onInterestsChanged() {
    setState(() => _interests = OnboardingState.interests.value);
  }

  Future<void> _load() async {
    _resetPaging();
    setState(() {
      _loading = true;
      _error = false;
      _loadingMore = false;
    });
    try {
      // Offline: the mock assets count as "the network", so the list comes from
      // the saved snapshots only — no repository call at all.
      final offline = _offline;
      final projects = offline
          ? await SavedProjectStore.instance.loadAll()
          : await _projects.getProjects();
      final categories = await _filters.getCategoryIds();
      final interests = await OnboardingState.readInterests();
      if (!offline) {
        unawaited(
          SavedProjectStore.instance.refresh(
            projects,
            SavedProjectsController.instance.ids,
          ),
        );
      }
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
    final total = _mainProjects.length;
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
      _savedScope = false;
      _distance = DistanceBand.semua;
      _condition = null;
    });
  }

  /// Leaves the saved collection without touching the category or the query —
  /// the other filters stay as the user set them.
  void _showAllProjects() {
    _resetPaging();
    setState(() => _savedScope = false);
  }

  /// Saved-scope recovery that keeps the collection: drop the category and the
  /// search so every saved project is reachable again.
  void _showAllSavedCategories() {
    _searchController.clear();
    _resetPaging();
    setState(() {
      _query = '';
      _category = 'semua';
    });
  }

  /// Map data is loaded on demand: the list never pays for an asset only the
  /// map and the filter sheet need.
  ///
  /// Concurrent callers share the in-flight read, so opening the filter sheet
  /// while the map is still loading waits for the reference location instead of
  /// showing a blank distance label.
  Future<void> _ensureMapData() {
    if (_mapData != null) return Future<void>.value();
    return _mapLoadFuture ??= _loadMapData();
  }

  Future<void> _loadMapData() async {
    setState(() {
      _mapLoading = true;
      _mapError = false;
    });
    try {
      final data = await _maps.getMapData();
      if (!mounted) return;
      setState(() {
        _mapData = data;
        _mapLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mapError = true;
        _mapLoading = false;
      });
    } finally {
      _mapLoadFuture = null;
    }
  }

  void _setMapMode(bool map) {
    setState(() => _mapMode = map);
    if (map) _ensureMapData();
  }

  ExploreFilterSelection get _selection => ExploreFilterSelection(
    category: _category,
    distance: _distance,
    condition: _condition,
  );

  Future<void> _openFilterSheet() async {
    // The distance group needs the mock reference location, so make sure the
    // map data is there before the sheet shows its labels.
    await _ensureMapData();
    if (!mounted) return;
    final selection = await showExploreFilterSheet(
      context,
      selection: _selection,
      userLocationLabel: _mapData?.userLocationLabel ?? '',
      countFor: (draft) => _applyFilters(
        selection: draft,
        query: _query,
        savedScope: _savedScope,
      ).length,
    );
    if (selection == null || !mounted) return;
    _resetPaging();
    setState(() {
      // The sheet no longer owns category, but applying its draft keeps the
      // rail selection intact.
      _distance = selection.distance;
      _condition = selection.condition;
    });
  }

  /// Map mode replaces the hidden rail with a compact chip. One picker, one
  /// category state, no second set of category buttons.
  Future<void> _pickCategory() async {
    final id = await showCategoryPickerSheet(
      context,
      categoryIds: _categoryIds,
      selectedId: _category,
    );
    if (id == null || !mounted) return;
    _resetPaging();
    setState(() => _category = id);
  }

  /// One filtering rule set for the page and for the sheet's live count.
  ///
  /// The saved collection, category, query, condition and distance are applied
  /// in that order. Distance/condition are skipped while the map data has not
  /// loaded yet — the sheet only opens after it has, so a visible filter can
  /// never silently match nothing.
  List<Project> _applyFilters({
    required ExploreFilterSelection selection,
    required String query,
    required bool savedScope,
  }) {
    final saved = SavedProjectsController.instance.ids;
    final mapData = _mapData;
    return _all.where((p) {
      final matchesSaved = !savedScope || saved.contains(p.id);
      final matchesCategory =
          selection.category == 'semua' || p.category == selection.category;
      final matchesQuery =
          query.isEmpty ||
          p.title.toLowerCase().contains(query) ||
          p.orgName.toLowerCase().contains(query) ||
          p.location.toLowerCase().contains(query);
      final matchesCondition =
          selection.condition == null ||
          mapData == null ||
          mapData.conditionOf(p.id) == selection.condition;
      final matchesDistance =
          selection.distance == DistanceBand.semua ||
          mapData == null ||
          selection.distance.matches(
            distanceKm(mapData.userLocation, LatLng(p.latitude, p.longitude)),
          );
      return matchesSaved &&
          matchesCategory &&
          matchesQuery &&
          matchesCondition &&
          matchesDistance;
    }).toList();
  }

  List<Project> get _visible {
    var list = _applyFilters(
      selection: _selection,
      query: _query,
      savedScope: _savedScope,
    );

    // Personalized sorting: interest matches first. The original index breaks
    // ties so equal-ranked projects keep the filter order.
    if (_interests.isNotEmpty) {
      final indexed = list.asMap().entries.toList()
        ..sort((a, b) {
          final byRank = _interestRank(a.value)
              .compareTo(_interestRank(b.value));
          return byRank != 0 ? byRank : a.key.compareTo(b.key);
        });
      list = [for (final entry in indexed) entry.value];
    }
    return list;
  }

  int _interestRank(Project project) =>
      InterestCategories.anyMatches(_interests, project.category) ? 0 : 1;

  /// The rail only exists in the plain Explore list: the saved collection is
  /// already personal, and a search, a category or a missing interest leaves
  /// nothing to personalise.
  bool get _railVisible =>
      !_savedScope &&
      _category == 'semua' &&
      _query.isEmpty &&
      _interests.any((id) => InterestCategories.categoriesOf(id).isNotEmpty);

  List<Project> get _forYouProjects => _railVisible
      ? _visible
            .where(
              (project) =>
                  InterestCategories.anyMatches(_interests, project.category),
            )
            .take(5)
            .toList()
      : const [];

  /// Projects shown in the main list. Cards already in the rail are removed so
  /// the same project never appears twice; paging counts this list.
  List<Project> get _mainProjects {
    final rail = _forYouProjects;
    if (rail.isEmpty) return _visible;
    final railIds = rail.map((project) => project.id).toSet();
    return _visible.where((project) => !railIds.contains(project.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final savedCount = SavedProjectsController.instance.ids.length;

    return Scaffold(
      body: Column(
        children: [
          ExploreHeader(
            searchController: _searchController,
            query: _query,
            onQueryChanged: (value) {
              _resetPaging();
              setState(() => _query = value.trim().toLowerCase());
            },
            onClearQuery: () {
              _searchController.clear();
              _resetPaging();
              setState(() => _query = '');
            },
            filterActiveCount: _selection.activeCount,
            onFilterPressed: _openFilterSheet,
            saved: _savedScope,
            savedCount: savedCount,
            onSavedChanged: (saved) {
              _resetPaging();
              setState(() => _savedScope = saved);
            },
          ),
          // In list mode the results line scrolls with the content (see
          // [_buildList]); only the map, which does not scroll, keeps it fixed.
          // The active filter tokens stay fixed with it, above the map (not
          // floating over its zoom and layer controls).
          if (_mapMode && !_loading && !_error) ...[
            ExploreResultsBar(
              count: visible.length,
              mapMode: true,
              onViewChanged: _setMapMode,
              categoryId: _category,
              onCategoryPressed: _pickCategory,
            ),
            if (_selection.activeCount > 0)
              ActiveFilterBar(
                selection: _selection,
                onChanged: (value) {
                  _resetPaging();
                  setState(() {
                    _distance = value.distance;
                    _condition = value.condition;
                  });
                },
                horizontalPadding: ExploreSpacing.x16,
              ),
          ],
          Expanded(child: _buildBody(visible)),
        ],
      ),
    );
  }

  /// Results line + category chips + active filter tokens. Shared by the
  /// filled and the empty list so the controls never disappear.
  List<Widget> _listControls(BuildContext context, int count) => [
    // The results line scrolls with the content, so the fixed header stays
    // under a sixth of the screen.
    ExploreResultsBar(count: count, mapMode: false, onViewChanged: _setMapMode),
    // The icon rail sits at the page margin, aligned with the cards.
    CategorySelector(
      categoryIds: _categoryIds,
      selectedId: _category,
      onSelected: (id) {
        _resetPaging();
        setState(() => _category = id);
      },
      horizontalPadding: ExploreSpacing.x16,
    ),
    // The category is already visible as the selected chip, so the token bar
    // only summarises the distance/condition filters from the sheet.
    if (_selection.activeCount > 0)
      ActiveFilterBar(
        selection: _selection,
        onChanged: (value) {
          _resetPaging();
          setState(() {
            _distance = value.distance;
            _condition = value.condition;
          });
        },
        horizontalPadding: ExploreSpacing.x16,
      ),
  ];

  /// The recovery choices depend on why the list is empty. The saved scope
  /// keeps its collection unless the user explicitly leaves it.
  Widget _emptyState(BuildContext context) {
    if (!_savedScope) {
      return EmptyState(
        icon: Icons.search_off,
        message: context.tr('explore.empty.title'),
        actionLabel: context.tr('explore.resetFilter'),
        onAction: _resetFilters,
      );
    }
    // Nothing saved yet: the invitation to save stays a single action.
    if (SavedProjectsController.instance.ids.isEmpty) {
      return EmptyState(
        icon: Icons.bookmark_outline,
        message: context.tr('explore.emptySaved.title'),
        actionLabel: context.tr('explore.viewAll'),
        onAction: _showAllProjects,
      );
    }
    // Saved projects exist but the other filters hide them.
    final message = _query.isNotEmpty
        ? context.tr('explore.emptySavedFiltered.search')
        : _category != 'semua'
        ? context.tr('explore.emptySavedFiltered.category', {
            'category': context.tr('cat.$_category'),
          })
        : context.tr('explore.emptySavedFiltered.title');
    return EmptyState(
      icon: Icons.search_off,
      message: message,
      actionLabel: context.tr('explore.viewAllCategories'),
      onAction: _showAllSavedCategories,
      secondaryLabel: context.tr('explore.viewAll'),
      onSecondary: _showAllProjects,
    );
  }

  Widget _buildBody(List<Project> visible) {
    if (_loading) {
      // The results line keeps its exact position from the loaded list, so the
      // count arriving does not shift the page. Header is fixed above.
      return ListView(
        key: const ValueKey('explore.projectList'),
        padding: EdgeInsets.zero,
        children: [
          ExploreResultsBar(
            count: 0,
            mapMode: false,
            onViewChanged: _setMapMode,
            loading: true,
          ),
          const SizedBox(height: ExploreSpacing.x24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: ExploreSpacing.x16),
            child: SkeletonCard(),
          ),
          const SizedBox(height: ExploreSpacing.x12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: ExploreSpacing.x16),
            child: SkeletonCard(),
          ),
        ],
      );
    }
    if (_error) {
      return ErrorState(onRetry: _load);
    }
    if (_mapMode) {
      return _buildMap(visible);
    }
    if (visible.isEmpty) {
      // The offline list can be empty for its own reason: nothing was saved
      // before losing the connection. Controls would not recover that, so it
      // keeps its own full-page state.
      if (_offline) {
        return EmptyState(
          icon: Icons.cloud_off,
          message: context.tr('p03_offline_empty_title'),
          actionLabel: context.tr('p03_offline_reload'),
          onAction: _load,
        );
      }
      // Zero results must not dead-end: the results line, chips and filter
      // tokens stay in the same scroll view, and only the area below them
      // becomes the empty state.
      return RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          key: const ValueKey('explore.projectList'),
          // The filled state fits one screen; without this the pull gesture
          // would have nothing to drag.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _listControls(context, visible.length),
              ),
            ),
            // SliverFillRemaining is the sliver form of "minHeight = the rest
            // of the viewport": it centres the state in the leftover space
            // and grows with the scroll view when the controls need it.
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(context),
            ),
          ],
        ),
      );
    }

    final forYou = _forYouProjects;
    final others = _mainProjects;
    final page = others.take(_visibleCount).toList();
    final sectionTitle = _savedScope
        ? context.tr('explore.savedProjects')
        : forYou.isNotEmpty
        ? context.tr('explore.moreProjects')
        : context.tr('explore.allProjects');
    final twoColumns = MediaQuery.sizeOf(context).width >= 600;

    Widget card(Project project) =>
        ProjectCard(project: project, onSavedChanged: () => setState(() {}));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const ValueKey('explore.projectList'),
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
          // The controls scroll with the content in list mode: the results
          // line, the category chips and any active sheet filters stay
          // visible in every state, including zero results.
          ..._listControls(context, visible.length),
          if (forYou.isNotEmpty) ...[
            const SizedBox(height: ExploreSpacing.x24),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExploreSpacing.x16,
              ),
              child: exploreSectionHeader(
                context,
                context.tr('explore.forYou'),
              ),
            ),
            const SizedBox(height: ExploreSpacing.x12),
            ForYouRail(
              key: const ValueKey('explore.forYouRail'),
              projects: forYou,
              onSavedChanged: () => setState(() {}),
            ),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: ExploreSpacing.x24),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ExploreSpacing.x16,
              ),
              child: exploreSectionHeader(context, sectionTitle),
            ),
            const SizedBox(height: ExploreSpacing.x12),
            if (twoColumns)
              for (var i = 0; i < page.length; i += 2) ...[
                if (i > 0) const SizedBox(height: ExploreSpacing.x12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExploreSpacing.x16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: card(page[i])),
                      const SizedBox(width: ExploreSpacing.x16),
                      Expanded(
                        child: i + 1 < page.length
                            ? card(page[i + 1])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ]
            else
              for (var i = 0; i < page.length; i++) ...[
                if (i > 0) const SizedBox(height: ExploreSpacing.x12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ExploreSpacing.x16,
                  ),
                  child: card(page[i]),
                ),
              ],
          ],
          // Small placeholder while the next page is appended.
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                ExploreSpacing.x16,
                ExploreSpacing.x12,
                ExploreSpacing.x16,
                0,
              ),
              child: Skeleton(height: 72, radius: 12),
            ),
          const SizedBox(height: ExploreSpacing.x24),
        ],
      ),
    );
  }

  Widget _buildMap(List<Project> visible) {
    if (_mapLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_mapError) return ErrorState(onRetry: _ensureMapData);
    final mapData = _mapData;
    if (mapData == null) return ErrorState(onRetry: _ensureMapData);

    if (visible.isEmpty) {
      return EmptyState(
        icon: Icons.map_outlined,
        message: context.tr('p03_map_empty'),
        actionLabel: context.tr('explore.resetFilter'),
        onAction: _resetFilters,
      );
    }

    return ExploreMap(
      projects: visible,
      mapData: mapData,
      userLocationLabel: mapData.userLocationLabel,
      showConservationLayer: _conservationLayer,
      onConservationLayerChanged: (value) =>
          setState(() => _conservationLayer = value),
      offline: _offline,
      tileProvider: widget.mapTileProvider,
      onOpenProject: (id) => context.push('/project/$id'),
    );
  }
}
