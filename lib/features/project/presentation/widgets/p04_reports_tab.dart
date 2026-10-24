import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/filter_chip_row.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../data/report_repository.dart';
import '../../domain/report.dart';
import '../p04_format.dart';
import '../p04_report_visuals.dart';
import 'p04_condition_chart.dart';
import 'p04_report_detail_sheet.dart';

/// Reports tab of P04.
///
/// The tab owns only presentation state (loading, error, visible page size).
/// [ReportPeriod] is held by the page so switching tabs cannot reset the
/// selected period, and every number/trend comes from [ReportRepository].
class P04ReportsTab extends StatefulWidget {
  const P04ReportsTab({
    super.key,
    required this.projectId,
    required this.locationName,
    required this.repository,
    required this.period,
    required this.onPeriodChanged,
  });

  /// Location/project id shared with the report mock data.
  final String projectId;

  /// Project location shown in the report detail sheet.
  final String locationName;

  final ReportRepository repository;

  /// Currently selected period, owned by the parent page.
  final ReportPeriod period;

  final ValueChanged<ReportPeriod> onPeriodChanged;

  @override
  State<P04ReportsTab> createState() => _P04ReportsTabState();
}

class _P04ReportsTabState extends State<P04ReportsTab>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 10;

  ReportSummary? _summary;
  List<MonthlyConditionPoint> _trend = const [];
  List<Report> _reports = const [];
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
  void didUpdateWidget(covariant P04ReportsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.repository != widget.repository ||
        oldWidget.period != widget.period) {
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
      final period = widget.period;
      final (summary, trend, reports) = await (
        repository.getReportSummary(
          projectId,
          period: period,
          verifiedOnly: true,
        ),
        repository.getMonthlyConditionTrend(projectId, period: period),
        repository.getReportsByLocation(
          projectId,
          period: period,
          verifiedOnly: true,
        ),
      ).wait;
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _summary = summary;
        _trend = trend;
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

  void _selectPeriod(String id) {
    final next = ReportPeriod.values.firstWhere(
      (period) => period.name == id,
      orElse: () => widget.period,
    );
    if (next == widget.period) return;
    widget.onPeriodChanged(next);
  }

  void _showMore() {
    setState(() => _visibleCount += _pageSize);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = Localizations.localeOf(context).languageCode;
    final options = [
      ChipOption(
        id: ReportPeriod.oneMonth.name,
        label: context.tr('p04_period_1m'),
      ),
      ChipOption(
        id: ReportPeriod.threeMonths.name,
        label: context.tr('p04_period_3m'),
      ),
      ChipOption(
        id: ReportPeriod.sixMonths.name,
        label: context.tr('p04_period_6m'),
      ),
      ChipOption(
        id: ReportPeriod.all.name,
        label: context.tr('p04_period_all'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.padding,
            12,
            AppDimens.padding,
            8,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.date_range_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                context.tr('p04_period_label'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        FilterChipRow(
          options: options,
          selectedId: widget.period.name,
          onSelected: _selectPeriod,
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildBody(lang)),
      ],
    );
  }

  Widget _buildBody(String lang) {
    if (_loading) return const _ReportsSkeleton();
    if (_error) return Center(child: ErrorState(onRetry: _load));

    final summary = _summary;
    final hasMetrics =
        summary != null &&
        (summary.totalWasteKg > 0 ||
            summary.totalAreaM2 > 0 ||
            summary.verifiedReportCount > 0);

    return ListView(
      key: const PageStorageKey('p04-reports-scroll'),
      primary: false,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.padding,
        8,
        AppDimens.padding,
        24,
      ),
      children: [
        if (hasMetrics) ...[
          _MetricsCard(summary: summary, lang: lang),
          const SizedBox(height: AppDimens.gap),
        ],
        P04ConditionChart(points: _trend),
        const SizedBox(height: AppDimens.gap),
        _ReportsSection(
          reports: _reports,
          visibleCount: _visibleCount,
          locationName: widget.locationName,
          repository: widget.repository,
          lang: lang,
          onLoadMore: _showMore,
        ),
      ],
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.summary, required this.lang});

  final ReportSummary summary;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (summary.totalWasteKg > 0)
        _MetricTile(
          key: const ValueKey('p04-metric-waste'),
          icon: Icons.delete_outline,
          label: context.tr('p04_metric_waste_label'),
          value: context.tr('p04_metric_waste_value', {
            'value': P04Format.number(summary.totalWasteKg, lang),
          }),
        ),
      if (summary.totalAreaM2 > 0)
        _MetricTile(
          key: const ValueKey('p04-metric-area'),
          icon: Icons.aspect_ratio_outlined,
          label: context.tr('p04_metric_area_label'),
          value: context.tr('p04_metric_area_value', {
            'value': P04Format.number(summary.totalAreaM2, lang),
          }),
        ),
      if (summary.verifiedReportCount > 0)
        _MetricTile(
          key: const ValueKey('p04-metric-verified'),
          icon: Icons.verified_outlined,
          label: context.tr('p04_metric_verified_label'),
          value: context.tr('p04_metric_count_value', {
            'value': P04Format.integer(summary.verifiedReportCount, lang),
          }),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('p04_metrics_title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppDimens.gap),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 300 ? 2 : 3;
                final width =
                    (constraints.maxWidth - AppDimens.gap * (columns - 1)) /
                    columns;
                return Wrap(
                  spacing: AppDimens.gap,
                  runSpacing: AppDimens.gap,
                  children: [
                    for (final tile in tiles)
                      SizedBox(width: width, child: tile),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.ocean),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsSection extends StatelessWidget {
  const _ReportsSection({
    required this.reports,
    required this.visibleCount,
    required this.locationName,
    required this.repository,
    required this.lang,
    required this.onLoadMore,
  });

  final List<Report> reports;
  final int visibleCount;
  final String locationName;
  final ReportRepository repository;
  final String lang;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final visible = reports.take(visibleCount).toList();
    final hasMore = reports.length > visibleCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('p04_reports_title'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (reports.isNotEmpty)
              Text(
                context.tr(
                  reports.length == 1
                      ? 'p04_reports_count_one'
                      : 'p04_reports_count',
                  {'n': P04Format.integer(reports.length, lang)},
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimens.gap),
        if (reports.isEmpty)
          SizedBox(
            height: 240,
            child: EmptyState(
              icon: Icons.description_outlined,
              message: context.tr('p04_reports_empty'),
            ),
          )
        else ...[
          for (final report in visible) ...[
            _ReportCard(
              report: report,
              locationName: locationName,
              repository: repository,
              lang: lang,
            ),
            const SizedBox(height: AppDimens.gap),
          ],
          if (hasMore)
            Center(
              child: OutlinedButton.icon(
                key: const ValueKey('p04-load-more'),
                onPressed: onLoadMore,
                icon: const Icon(Icons.expand_more),
                label: Text(context.tr('p04_reports_load_more')),
              ),
            ),
        ],
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.locationName,
    required this.repository,
    required this.lang,
  });

  final Report report;
  final String locationName;
  final ReportRepository repository;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final categoryColor = context.p04CategoryColor(report.category);

    return Card(
      key: ValueKey('p04-report-${report.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showP04ReportDetailSheet(
          context,
          reportId: report.id,
          locationName: locationName,
          repository: repository,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
                    ),
                    child: Icon(
                      context.p04CategoryIcon(report.category),
                      size: 20,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(width: AppDimens.gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          P04Format.date(report.reportedAt.toLocal(), lang),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.gap),
                  _ReportThumbnail(photoPath: report.photoPaths.firstOrNull),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ReportChip(
                    icon: Icons.speed_outlined,
                    label: context.p04SeverityLabel(report.severity),
                    color: context.p04SeverityColor(report.severity),
                  ),
                  _ReportChip(
                    icon: context.p04StatusIcon(report.status),
                    label: context.p04StatusLabel(report.status),
                    color: context.p04StatusColor(report.status),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportThumbnail extends StatelessWidget {
  const _ReportThumbnail({required this.photoPath});

  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      child: SizedBox(
        width: 64,
        height: 64,
        child: photoPath == null
            ? const _ThumbnailPlaceholder()
            : Image.asset(
                photoPath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _ThumbnailPlaceholder(),
              ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.border,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 22,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _ReportChip extends StatelessWidget {
  const _ReportChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(
        AppDimens.padding,
        8,
        AppDimens.padding,
        24,
      ),
      children: const [
        Skeleton(height: 118, radius: 16),
        SizedBox(height: 12),
        Skeleton(height: 280, radius: 16),
        SizedBox(height: 12),
        Skeleton(height: 96, radius: 16),
        SizedBox(height: 12),
        Skeleton(height: 96, radius: 16),
        SizedBox(height: 12),
        Skeleton(height: 96, radius: 16),
      ],
    );
  }
}
