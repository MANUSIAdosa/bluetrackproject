import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show TileProvider;
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/login_prompt_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../project/data/project_data_repositories.dart';
import '../../project/data/report_repository.dart';
import '../../project/domain/report.dart';
import '../../project/presentation/p04_format.dart';
import '../../project/presentation/p04_report_visuals.dart';
import '../data/my_reports_config.dart';
import '../data/my_reports_store.dart';
import 'widgets/my_report_card.dart';
import 'widgets/my_report_detail_sheet.dart';
import 'widgets/my_reports_filter_sheet.dart';

/// My Reports — the signed-in user's citizen reports.
///
/// The page is protected: signed-out visitors see the same login prompt as My
/// Impact and return here after signing in. The repository seeds the shared
/// session collection; both this page and the submit flow then read/write the
/// same [MyReportsStore]. The status filter is applied locally.
class MyReportsPage extends StatefulWidget {
  const MyReportsPage({
    super.key,
    this.repository,
    this.store,
    this.userId = kMockCurrentUserId,
    this.mapTileProvider,
  });

  /// Repository used to seed the session collection with bundled mock reports.
  final ReportRepository? repository;

  /// Session collection shared with the report submission flow.
  final MyReportsStore? store;

  /// Owner of the reports. Mock auth has no profile yet, so this defaults to
  /// the mock user id; [kMockCurrentUserId] documents the replacement point.
  final String userId;

  /// Test seam for the map tiles inside the detail sheet.
  final TileProvider? mapTileProvider;

  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  late final ReportRepository _repository =
      widget.repository ?? ProjectDataRepositories.reports;
  late final MyReportsStore _store = widget.store ?? MyReportsStore.instance;

  List<Report>? _reports;
  bool _loading = false;
  bool _error = false;
  ReportStatus? _selectedStatus;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    AuthController.instance.addListener(_onAuthChanged);
    _store.addListener(_onStoreChanged);
    if (AuthController.instance.signedIn) {
      final cachedReports = _reportsForUser();
      if (cachedReports.isNotEmpty) _reports = cachedReports;
      _load();
    }
  }

  @override
  void dispose() {
    AuthController.instance.removeListener(_onAuthChanged);
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (!AuthController.instance.signedIn) {
      setState(() {
        _reports = null;
        _loading = false;
        _error = false;
        _selectedStatus = null;
        _requestId++;
      });
      return;
    }
    if (_reports == null && !_loading) {
      final cachedReports = _reportsForUser();
      if (cachedReports.isNotEmpty) {
        setState(() => _reports = cachedReports);
      }
      _load();
    }
  }

  void _onStoreChanged() {
    if (!mounted || !AuthController.instance.signedIn) return;
    final reports = _reportsForUser();
    setState(() {
      _reports = reports;
      if (reports.isNotEmpty) {
        _loading = false;
        _error = false;
      }
    });
  }

  List<Report> _reportsForUser() {
    final reports = _store.reports
        .where((report) => report.reporterId == widget.userId)
        .toList()
      ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    return reports;
  }

  Future<void> _load({bool showSkeleton = true}) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = showSkeleton && _reports == null;
      _error = false;
    });

    try {
      final seedReports = await _repository.getReportsByUser(widget.userId);
      if (!mounted || requestId != _requestId) return;
      _store.addAllIfMissing(seedReports);
      setState(() {
        _reports = _reportsForUser();
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      final cachedReports = _reportsForUser();
      setState(() {
        _reports = cachedReports.isEmpty ? null : cachedReports;
        _loading = false;
        _error = cachedReports.isEmpty;
      });
    }
  }

  void _selectFilter(String id) {
    setState(() {
      _selectedStatus = id == 'all' ? null : ReportStatus.fromId(id);
    });
  }

  Future<void> _openReportForm() async {
    await context.push<void>(Routes.report);
  }

  List<Report> _visibleReports(List<Report> reports) {
    final selected = _selectedStatus;
    if (selected == null) return reports;
    return reports.where((report) => report.status == selected).toList();
  }

  Future<void> _openFilter() async {
    final reports = _reports ?? const <Report>[];
    final counts = <String, int>{
      'all': reports.length,
      for (final status in ReportStatus.values)
        status.id: reports.where((report) => report.status == status).length,
    };
    final id = await showMyReportsFilterSheet(
      context,
      selectedId: _selectedStatus?.id ?? 'all',
      counts: counts,
    );
    if (!mounted || id == null) return;
    _selectFilter(id);
  }

  Widget _refreshableState(BuildContext context, Widget state) {
    return RefreshIndicator(
      onRefresh: () => _load(showSkeleton: false),
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: constraints.maxHeight, child: state)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthController.instance,
      builder: (context, _) {
        final signedIn = AuthController.instance.signedIn;
        final textTheme = Theme.of(context).textTheme;
        final reports = signedIn ? _reports : null;
        final selected = _selectedStatus;
        final visible = reports == null ? null : _visibleReports(reports);
        // With no reports at all the empty state already owns the create
        // action; when a filter hides every report the page must not invite
        // another report, so the floating action stays out of both states.
        final showCreateAction = visible != null && visible.isNotEmpty;

        final subtitle = reports == null
            ? null
            : selected == null
            ? context.tr('my_reports.count', {'n': '${reports.length}'})
            : context.tr('my_reports.filtered_count', {
                'status': context.p04StatusLabel(selected),
                'n': '${visible!.length}',
              });

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            titleSpacing: AppDimens.padding,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('detail.myReports'),
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            actions: signedIn
                ? [
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Badge(
                        isLabelVisible: selected != null,
                        smallSize: 8,
                        backgroundColor: AppColors.coral,
                        child: IconButton(
                          key: const ValueKey('my-reports-filter-button'),
                          tooltip: context.tr('my_reports.filter_title'),
                          onPressed: _openFilter,
                          icon: Icon(
                            Icons.tune,
                            color: selected == null
                                ? AppColors.textPrimary
                                : AppColors.ocean,
                          ),
                        ),
                      ),
                    ),
                  ]
                : null,
          ),
          floatingActionButton: showCreateAction
              ? FloatingActionButton.extended(
                  key: const ValueKey('my-reports-create'),
                  onPressed: _openReportForm,
                  backgroundColor: AppColors.ocean,
                  foregroundColor: AppColors.surface,
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('my_reports.create')),
                )
              : null,
          body: !signedIn
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimens.padding),
                  child: LoginPromptCard(returnLocation: Routes.myReports),
                )
              : _buildBody(context, reports),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, List<Report>? reports) {
    if (_loading) return const _MyReportsSkeleton();

    if (_error) {
      return ErrorState(
        message: context.tr('my_reports.load_error'),
        onRetry: _load,
      );
    }

    final all = reports ?? const <Report>[];
    if (all.isEmpty) {
      return _refreshableState(
        context,
        EmptyState(
          icon: Icons.waves,
          title: context.tr('my_reports.empty_title'),
          message: context.tr('my_reports.empty'),
          actionLabel: context.tr('my_reports.create'),
          onAction: _openReportForm,
        ),
      );
    }

    final selected = _selectedStatus;
    final visible = _visibleReports(all);

    // Reports exist but none match the active status: the user can clear the
    // filter, but nothing here invites another report.
    if (visible.isEmpty && selected != null) {
      return _refreshableState(
        context,
        EmptyState(
          icon: Icons.filter_alt_off_outlined,
          message: context.tr('my_reports.empty_filter', {
            'status': context.p04StatusLabel(selected),
          }),
          actionLabel: context.tr('my_reports.show_all'),
          onAction: () => _selectFilter('all'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(showSkeleton: false),
      child: ListView.separated(
        key: const ValueKey('my-reports-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.padding,
          12,
          AppDimens.padding,
          96,
        ),
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final report = visible[index];
          return MyReportCard(
            report: report,
            onTap: () => showMyReportDetailSheet(
              context,
              report: report,
              mapTileProvider: widget.mapTileProvider,
            ),
            onCompletionProofTap:
                report.status == ReportStatus.completed &&
                    report.hasCompletionProof
                ? () => showMyReportDetailSheet(
                    context,
                    report: report,
                    mapTileProvider: widget.mapTileProvider,
                    openCompletionProof: true,
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// Card-shaped placeholders that mirror the populated report list.
class _MyReportsSkeleton extends StatelessWidget {
  const _MyReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.tr('my_reports.loading'),
      child: ListView(
        key: const ValueKey('my-reports-skeleton'),
        padding: const EdgeInsets.fromLTRB(
          AppDimens.padding,
          12,
          AppDimens.padding,
          96,
        ),
        children: [
          for (var i = 0; i < 4; i++) ...[
            const _MyReportCardSkeleton(),
            if (i < 3) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MyReportCardSkeleton extends StatelessWidget {
  const _MyReportCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(color: AppColors.border),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Skeleton(width: 64, height: 64, radius: 14),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Skeleton(width: 96, height: 12, radius: 6),
                          const SizedBox(height: 8),
                          const Skeleton(height: 16, radius: 6),
                          const SizedBox(height: 5),
                          const Skeleton(width: 170, height: 16, radius: 6),
                          const SizedBox(height: 8),
                          const Skeleton(width: 132, height: 12, radius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Skeleton(width: 86, height: 24, radius: 999),
                    const SizedBox(width: 10),
                    const Skeleton(width: 96, height: 14, radius: 7),
                    const Spacer(),
                    const Skeleton(width: 20, height: 20, radius: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyReportsFilterOption {
  const _MyReportsFilterOption({
    required this.id,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final int count;
  final IconData icon;
  final Color color;
}

class _MyReportsFilterChip extends StatelessWidget {
  const _MyReportsFilterChip({
    required this.option,
    required this.selected,
    required this.languageCode,
    required this.onTap,
  });

  final _MyReportsFilterOption option;
  final bool selected;
  final String languageCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.surface : option.color;
    final countBackground = selected
        ? AppColors.surface.withValues(alpha: 0.18)
        : option.color.withValues(alpha: 0.1);

    return Semantics(
      key: ValueKey('my-reports-filter-${option.id}'),
      button: true,
      selected: selected,
      label: context.tr('my_reports.filter_count', {
        'label': option.label,
        'count': P04Format.integer(option.count, languageCode),
      }),
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? AppColors.ocean : AppColors.surface,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? AppColors.ocean : AppColors.border,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(option.icon, size: 16, color: foreground),
                    const SizedBox(width: 7),
                    Text(
                      option.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected
                            ? AppColors.surface
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: countBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        P04Format.integer(option.count, languageCode),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.surface
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
