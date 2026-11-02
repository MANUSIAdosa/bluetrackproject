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
import '../../project/presentation/p04_report_visuals.dart';
import '../data/my_reports_config.dart';
import 'widgets/my_report_card.dart';
import 'widgets/my_report_detail_sheet.dart';
import 'widgets/my_reports_filter_sheet.dart';

/// My Reports — the signed-in user's citizen reports.
///
/// The page is protected: signed-out visitors see the same login prompt as My
/// Impact and return here after signing in. Reports are loaded once and the
/// status filter is applied locally, so the page can tell "you have no reports
/// yet" apart from "no reports in this status".
class MyReportsPage extends StatefulWidget {
  const MyReportsPage({
    super.key,
    this.repository,
    this.userId = kMockCurrentUserId,
    this.mapTileProvider,
  });

  /// Test/demo override for the report data source.
  final ReportRepository? repository;

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

  List<Report>? _reports;
  bool _loading = false;
  bool _error = false;
  ReportStatus? _selectedStatus;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    AuthController.instance.addListener(_onAuthChanged);
    if (AuthController.instance.signedIn) _load();
  }

  @override
  void dispose() {
    AuthController.instance.removeListener(_onAuthChanged);
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
    if (_reports == null && !_loading) _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final reports = await _repository.getReportsByUser(widget.userId);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _reports = reports;
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

  void _selectFilter(String id) {
    setState(() {
      _selectedStatus = id == 'all' ? null : ReportStatus.fromId(id);
    });
  }

  Future<void> _openReportForm() async {
    await context.push(Routes.report);
    if (!mounted) return;
    _load();
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthController.instance,
      builder: (context, _) {
        final signedIn = AuthController.instance.signedIn;
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
                  style: const TextStyle(
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (reports != null && reports.isNotEmpty)
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
            ],
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
      return EmptyState(
        icon: Icons.description_outlined,
        message: context.tr('my_reports.empty'),
        actionLabel: context.tr('my_reports.create'),
        onAction: _openReportForm,
      );
    }

    final selected = _selectedStatus;
    final visible = _visibleReports(all);

    // Reports exist but none match the active status: the user can clear the
    // filter, but nothing here invites another report.
    if (visible.isEmpty && selected != null) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        message: context.tr('my_reports.empty_filter', {
          'status': context.p04StatusLabel(selected),
        }),
        actionLabel: context.tr('my_reports.show_all'),
        onAction: () => _selectFilter('all'),
      );
    }

    return ListView.separated(
      key: const ValueKey('my-reports-list'),
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
        );
      },
    );
  }
}

/// Filter and card placeholders that mirror the populated page's rhythm.
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
            const Skeleton(height: 116, radius: AppDimens.cardRadius),
            if (i < 3) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
