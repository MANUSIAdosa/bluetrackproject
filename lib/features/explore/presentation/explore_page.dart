import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show TileProvider;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/state/app_state.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/filter_chip_row.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/project_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../repositories.dart';
import '../data/explore_map_repository.dart';
import '../data/project_repository.dart';
import '../data/saved_project_store.dart';
import '../domain/explore_map_data.dart';
import '../domain/project.dart';
import 'widgets/explore_list_widgets.dart';
import 'widgets/explore_map.dart';
import 'widgets/filter_sheet.dart';

/// P03 — Explore (P03 map + list).
///
/// - Search, a single-select category chip row, a saved-projects toggle next to
///   the search field (Hive), interest sorting, loading / empty / error states,
///   notification bell.
/// - One control represents one context: the chip row filters by category, the
///   bookmark button filters the saved collection, and the segmented button
///   switches the view mode.
/// - The list is paged: only [_pageSize] projects at a time, the next page
///   appended when the user scrolls near the bottom.
/// - The filter sheet adds the distance and condition groups; both modes — list
///   and map — read the same filtered result set, so switching never resets a
///   filter.
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
  ExploreMapRepository get _maps =>
      widget.mapRepository ?? const MockExploreMapRepository();

  bool get _offline => OfflineController.instance.offline;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    OfflineController.instance.addListener(_onOfflineChanged);
    _load();
  }

  @override
  void dispose() {
    OfflineController.instance.removeListener(_onOfflineChanged);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
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
      _savedOnly = false;
      _distance = DistanceBand.semua;
      _condition = null;
    });
  }

  /// Leaves the saved collection without touching the category or the query —
  /// the other filters stay as the user set them.
  void _showAllProjects() {
    _resetPaging();
    setState(() => _savedOnly = false);
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
    );
    if (selection == null || !mounted) return;
    _resetPaging();
    setState(() {
      _category = selection.category;
      _distance = selection.distance;
      _condition = selection.condition;
    });
  }

  List<Project> get _visible {
    // One context per control, applied in that order: the saved collection,
    // then the category chip, then the search query, then the sheet groups.
    final saved = SavedProjectsController.instance.ids;
    final mapData = _mapData;
    var list = _all.where((p) {
      final matchesSaved = !_savedOnly || saved.contains(p.id);
      final matchesCategory = _category == 'semua' || p.category == _category;
      final matchesQuery =
          _query.isEmpty ||
          p.title.toLowerCase().contains(_query) ||
          p.orgName.toLowerCase().contains(_query) ||
          p.location.toLowerCase().contains(_query);
      final matchesCondition =
          _condition == null ||
          mapData == null ||
          mapData.conditionOf(p.id) == _condition;
      final matchesDistance =
          _distance == DistanceBand.semua ||
          mapData == null ||
          _distance.matches(
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
                FilterButton(
                  key: const ValueKey('explore.filterButton'),
                  activeCount: _selection.activeCount,
                  onPressed: _openFilterSheet,
                ),
                const SizedBox(width: 8),
                SavedFilterButton(
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
          ListMapToggle(mapMode: _mapMode, onChanged: _setMapMode),
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
            exploreSectionHeader(context.tr('explore.forYou')),
            ForYouRail(
              key: const ValueKey('explore.forYouRail'),
              projects: forYou,
              onSavedChanged: () => setState(() {}),
            ),
            const SizedBox(height: 8),
            exploreSectionHeader(context.tr('explore.projects')),
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: Text(context.tr('p03_map_layer_conservation')),
              selected: _conservationLayer,
              showCheckmark: false,
              onSelected: (value) => setState(() => _conservationLayer = value),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: visible.isEmpty
              ? EmptyState(
                  icon: Icons.map_outlined,
                  message: context.tr('p03_map_empty'),
                  actionLabel: context.tr('explore.resetFilter'),
                  onAction: _resetFilters,
                )
              : ExploreMap(
                  projects: visible,
                  mapData: mapData,
                  userLocationLabel: mapData.userLocationLabel,
                  showConservationLayer: _conservationLayer,
                  offline: _offline,
                  tileProvider: widget.mapTileProvider,
                  onOpenProject: (id) => context.push('/project/$id'),
                ),
        ),
      ],
    );
  }
}
