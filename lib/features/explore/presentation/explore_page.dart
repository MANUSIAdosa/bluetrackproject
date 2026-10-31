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
import '../domain/project.dart';
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
    _load();
  }

  @override
  void dispose() {
    OfflineController.instance.removeListener(_onOfflineChanged);
    SavedProjectsController.instance.removeListener(_onSavedProjectsChanged);
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
      categoryIds: _categoryIds,
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
      _category = selection.category;
      _distance = selection.distance;
      _condition = selection.condition;
    });
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
            distanceKm(
              mapData.userLocation,
              LatLng(p.latitude, p.longitude),
            ),
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
            mapMode: _mapMode,
            onViewChanged: _setMapMode,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: ExploreScopeSwitch(
              saved: _savedScope,
              savedCount: savedCount,
              onChanged: (saved) {
                _resetPaging();
                setState(() => _savedScope = saved);
              },
            ),
          ),
          if (!_loading && !_error) ExploreResultsBar(count: visible.length),
          Expanded(child: _buildBody(visible)),
        ],
      ),
    );
  }

  Widget _buildBody(List<Project> visible) {
    if (_loading) {
      return ListView(
        key: const ValueKey('explore.projectList'),
        padding: const EdgeInsets.all(16),
        children: const [SkeletonCard(), SizedBox(height: 16), SkeletonCard()],
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
      // before losing the connection.
      if (_offline) {
        return EmptyState(
          icon: Icons.cloud_off,
          message: context.tr('p03_offline_empty_title'),
          actionLabel: context.tr('p03_offline_reload'),
          onAction: _load,
        );
      }
      // Two different failures behind the same saved scope: nothing has been
      // saved yet, or the saved projects do not match the other filters.
      if (_savedScope) {
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
    // rail stays out of the way while that scope is active.
    final forYou = (_savedScope || _interests.isEmpty)
        ? const <Project>[]
        : visible
              .where((p) => _interests.contains(p.category))
              .take(5)
              .toList();
    final page = visible.take(_visibleCount).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const ValueKey('explore.projectList'),
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          // Secondary controls live inside the scroll view: they are useful at
          // the top, but must not permanently eat half the viewport.
          CategorySelector(
            categoryIds: _categoryIds,
            selectedId: _category,
            onSelected: (id) {
              _resetPaging();
              setState(() => _category = id);
            },
            horizontalPadding: 0,
          ),
          if (_selection.activeCount > 0)
            ActiveFilterBar(
              selection: _selection,
              onChanged: (value) {
                _resetPaging();
                setState(() {
                  _category = value.category;
                  _distance = value.distance;
                  _condition = value.condition;
                });
              },
              horizontalPadding: 0,
            ),
          if (forYou.isNotEmpty && _category == 'semua' && _query.isEmpty) ...[
            exploreSectionHeader(context.tr('explore.forYou')),
            ForYouRail(
              key: const ValueKey('explore.forYouRail'),
              projects: forYou,
              onSavedChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
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
