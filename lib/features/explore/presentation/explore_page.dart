import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/filter_chip_row.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/skeleton.dart';
import '../domain/project.dart';
import '../../repositories.dart';
import 'widgets/project_card.dart';

/// P03 — Explore (list mode).
///
/// - Search, category chips (incl. "Tersimpan" via Hive), interest sorting,
///   loading / empty / error states, notification bell.
/// - Map mode is a query-param sibling of this page (deferred: see
///   [explore.mapUnavailable]).
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _searchController = TextEditingController();

  List<Project> _all = const [];
  List<String> _categoryIds = const ['semua'];
  List<String> _interests = const [];

  String _category = 'semua';
  String _query = '';
  bool _loading = true;
  bool _error = false;
  bool _mapMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final projects = await Repositories.projects.getProjects();
      final categories = await Repositories.filters.getCategoryIds();
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
      setState(() => _error = true);
    }
  }

  List<Project> get _visible {
    final saved = SavedProjectsController.instance.ids;
    var list = _all.where((p) {
      final matchesCategory = _category == 'semua' ||
          (_category == 'tersimpan' ? saved.contains(p.id) : p.category == _category);
      final matchesQuery = _query.isEmpty ||
          p.title.toLowerCase().contains(_query) ||
          p.orgName.toLowerCase().contains(_query) ||
          p.location.toLowerCase().contains(_query);
      return matchesCategory && matchesQuery;
    }).toList();

    // Personalized sorting: interest matches first.
    if (_interests.isNotEmpty) {
      list = [...list]..sort((a, b) {
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
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          FilterChipRow(
            options: [
              for (final id in _categoryIds)
                ChipOption(id: id, label: context.tr('cat.$id')),
              ChipOption(
                id: 'tersimpan',
                label: savedCount > 0
                    ? '${context.tr('cat.tersimpan')} ($savedCount)'
                    : context.tr('cat.tersimpan'),
              ),
            ],
            selectedId: _category,
            onSelected: (id) => setState(() => _category = id),
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
        children: const [
          SkeletonCard(),
          SizedBox(height: 16),
          SkeletonCard(),
        ],
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
      final savedEmpty = _category == 'tersimpan';
      return EmptyState(
        icon: savedEmpty ? Icons.bookmark_outline : Icons.search_off,
        message: context.tr(
          savedEmpty ? 'explore.emptySaved.title' : 'explore.empty.title',
        ),
        actionLabel: savedEmpty ? context.tr('common.retry') : null,
        onAction: savedEmpty
            ? () => setState(() => _category = 'semua')
            : null,
      );
    }

    final forYou = _interests.isEmpty
        ? const <Project>[]
        : visible
            .where((p) => _interests.contains(p.category))
            .take(5)
            .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (forYou.isNotEmpty && _category == 'semua' && _query.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.tr('explore.forYou'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: forYou.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => SizedBox(
                  width: 260,
                  child: ProjectCard(
                    project: forYou[i],
                    onSavedChanged: () => setState(() {}),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.tr('explore.projects'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          for (final project in visible) ...[
            ProjectCard(
              project: project,
              onSavedChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
          ],
        ],
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
      child: Row(
        children: [
          SegmentedButton<bool>(
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
          const Spacer(),
          const Icon(Icons.sort, size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
