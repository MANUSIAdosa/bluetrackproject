import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/filter_chip_row.dart';
import '../../../shared/widgets/login_prompt_card.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../../shared/widgets/progress_ring.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/impact_repository.dart';
import '../domain/impact_overview.dart';

/// P09 My Impact — the signed-in user's contribution dashboard.
///
/// The summary totals, monthly goal and both chart windows come from
/// [ImpactRepository]; this page only formats and lays them out. Signed-out
/// users keep the P02 login prompt in place instead of being redirected away
/// from the tab.
class ImpactPage extends StatefulWidget {
  const ImpactPage({super.key, this.repository});

  /// Test seam — the router keeps constructing `const ImpactPage()`.
  final ImpactRepository? repository;

  @override
  State<ImpactPage> createState() => _ImpactPageState();
}

enum _ImpactStatus { loading, ready, empty, error }

class _ImpactPageState extends State<ImpactPage> {
  ImpactOverview? _overview;
  String? _displayName;
  _ImpactStatus _status = _ImpactStatus.loading;
  ImpactRange _range = ImpactRange.sixMonths;
  int _requestId = 0;

  ImpactRepository get _repository =>
      widget.repository ?? const MockImpactRepository();

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
        _overview = null;
        _displayName = null;
        _status = _ImpactStatus.loading;
        _range = ImpactRange.sixMonths;
        _requestId++;
      });
      return;
    }
    if (_overview == null) _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _status = _ImpactStatus.loading;
      _overview = null;
    });

    try {
      final overview = await _repository.getOverview();

      String? displayName;
      try {
        displayName = await AuthRepository.instance.readDisplayName();
      } catch (_) {
        // A storage failure must not block the contribution content; the page
        // falls back to the localized generic greeting.
      }

      if (!mounted || requestId != _requestId) return;
      setState(() {
        _overview = overview;
        _displayName = displayName;
        _status = overview.hasContributions
            ? _ImpactStatus.ready
            : _ImpactStatus.empty;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _overview = null;
        _status = _ImpactStatus.error;
      });
    }
  }

  void _onRangeSelected(String id) {
    final range = ImpactRange.fromId(id);
    if (range == null || range == _range) return;
    setState(() => _range = range);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('nav.impact')),
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: ListenableBuilder(
        listenable: AuthController.instance,
        builder: (context, _) {
          if (!AuthController.instance.signedIn) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimens.padding),
              child: LoginPromptCard(returnLocation: '/impact'),
            );
          }

          if (_status == _ImpactStatus.error) {
            return _buildFeedback(
              context,
              ErrorState(
                message: context.tr('impact.loadError'),
                onRetry: _load,
              ),
            );
          }
          if (_status == _ImpactStatus.empty) {
            return _buildFeedback(
              context,
              EmptyState(
                icon: Icons.waves_outlined,
                message: context.tr('impact.empty.message'),
                actionLabel: context.tr('report_title'),
                onAction: () => context.push(Routes.report),
              ),
            );
          }

          final overview = _overview;
          if (_status == _ImpactStatus.loading || overview == null) {
            return const _ImpactLoadingView();
          }
          return _buildContent(context, overview);
        },
      ),
    );
  }

  Widget _buildFeedback(BuildContext context, Widget state) {
    final name = _displayName ?? context.tr('impact.greetingFallback');
    return Padding(
      padding: const EdgeInsets.all(AppDimens.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ImpactGreeting(name: name),
          const SizedBox(height: AppDimens.padding),
          Expanded(child: state),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ImpactOverview overview) {
    final lang = Localizations.localeOf(context).languageCode;
    final name = _displayName ?? context.tr('impact.greetingFallback');

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.padding),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.padding),
          child: _ImpactGreeting(name: name),
        ),
        const SizedBox(height: AppDimens.padding),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.padding),
          child: _ImpactGoalCard(goal: overview.goal),
        ),
        const SizedBox(height: AppDimens.padding),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.padding),
          child: GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppDimens.gap,
              crossAxisSpacing: AppDimens.gap,
              mainAxisExtent: 140,
            ),
            children: [
              _ImpactStatCard(
                key: const ValueKey('impact-stat-reports'),
                icon: Icons.assignment_turned_in_outlined,
                color: AppColors.ocean,
                value: Formatters.number(overview.summary.reports, lang),
                label: context.tr('impact.stat.reports'),
              ),
              _ImpactStatCard(
                key: const ValueKey('impact-stat-actions'),
                icon: Icons.groups_2_outlined,
                color: AppColors.teal,
                value: Formatters.number(overview.summary.actions, lang),
                label: context.tr('impact.stat.actions'),
              ),
              _ImpactStatCard(
                key: const ValueKey('impact-stat-waste'),
                icon: Icons.recycling_outlined,
                color: AppColors.coral,
                value:
                    '${Formatters.number(overview.summary.wasteKg, lang)} '
                    '${context.tr('impact.unit.kg')}',
                label: context.tr('impact.stat.waste'),
              ),
              _ImpactStatCard(
                key: const ValueKey('impact-stat-support'),
                icon: Icons.volunteer_activism_outlined,
                color: AppColors.oceanDeep,
                value: Formatters.currency(
                  overview.summary.supportAmount,
                  lang,
                ),
                label: context.tr('impact.stat.support'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.padding),
        // FilterChipRow owns its horizontal 16dp padding, so it stays outside
        // the page's inner padding and aligns with the cards above.
        FilterChipRow(
          options: [
            ChipOption(
              id: ImpactRange.sixMonths.id,
              label: context.tr('impact.range.sixMonths'),
            ),
            ChipOption(
              id: ImpactRange.oneYear.id,
              label: context.tr('impact.range.oneYear'),
            ),
          ],
          selectedId: _range.id,
          onSelected: _onRangeSelected,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.padding),
          child: _MonthlyImpactChart(
            points: overview.chartFor(_range),
            months: _range.months,
          ),
        ),
      ],
    );
  }
}

/// Greeting block shared by the ready, empty and error states.
class _ImpactGreeting extends StatelessWidget {
  const _ImpactGreeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('impact.greeting', {'name': name}),
          style: const TextStyle(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('impact.subtitle'),
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// "Target Bulan Ini" card. The percentage and reference month come from the
/// repository, so the device date never changes the result.
class _ImpactGoalCard extends StatelessWidget {
  const _ImpactGoalCard({required this.goal});

  final ImpactGoal goal;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final month = goal.month;
    final monthLabel = month == null
        ? null
        : DateFormat.yMMMM(_intlLocale(lang)).format(month);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.padding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ringSize = constraints.maxWidth < 260 ? 84.0 : 96.0;

            return Row(
              children: [
                ProgressRing(
                  key: const ValueKey('impact-goal-ring'),
                  value: goal.progress,
                  size: ringSize,
                ),
                const SizedBox(width: AppDimens.padding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('impact.goal.title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (monthLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          monthLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        context.tr('impact.goal.progress', {
                          'current': Formatters.number(goal.completed, lang),
                          'target': Formatters.number(goal.target, lang),
                        }),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One of the four 2 x 2 summary cards.
class _ImpactStatCard extends StatelessWidget {
  const _ImpactStatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar chart for the selected range: reports plus joined actions per month.
class _MonthlyImpactChart extends StatelessWidget {
  const _MonthlyImpactChart({required this.points, required this.months});

  /// Oldest month first, already filtered by the repository.
  final List<ImpactContribution> points;
  final int months;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final maxActivity = points.fold<int>(
      0,
      (max, point) => math.max(max, point.activityCount),
    );
    final interval = math.max(1, (maxActivity / 4).ceil());
    final maxY = math.max(
      4,
      ((maxActivity + interval) / interval).ceil() * interval,
    );
    // Twelve bars need a slimmer rod to stay readable on a 320dp screen.
    final barWidth = points.length > ImpactRange.sixMonths.months ? 10.0 : 18.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('impact.chart.title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('impact.chart.subtitle', {'months': '$months'}),
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.padding),
            SizedBox(
              key: const ValueKey('impact-monthly-chart'),
              height: 220,
              child: BarChart(
                _chartData(
                  context,
                  lang,
                  maxY.toDouble(),
                  interval.toDouble(),
                  barWidth,
                ),
                duration: const Duration(milliseconds: 240),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartData _chartData(
    BuildContext context,
    String lang,
    double maxY,
    double interval,
    double barWidth,
  ) {
    return BarChartData(
      minY: 0,
      maxY: maxY,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) => const FlLine(
          color: AppColors.border,
          strokeWidth: 1,
          dashArray: [4, 4],
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(
                  Formatters.number(value, lang),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= points.length) {
                return const SizedBox.shrink();
              }
              // Twelve labels would collide at 320dp; keep every other month.
              if (points.length > ImpactRange.sixMonths.months &&
                  index.isEven) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(
                  _monthShort(points[index].month, lang),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AppColors.oceanDeep,
          tooltipBorderRadius: BorderRadius.circular(8),
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final point = points[group.x];
            return BarTooltipItem(
              context.tr('impact.chart.tooltip', {
                'month': _monthYear(point.month, lang),
                'n': Formatters.number(point.activityCount, lang),
              }),
              const TextStyle(
                color: AppColors.surface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
      ),
      barGroups: [
        for (var i = 0; i < points.length; i++)
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: points[i].activityCount.toDouble(),
                width: barWidth,
                color: AppColors.ocean,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _monthShort(DateTime month, String lang) =>
      DateFormat.MMM(_intlLocale(lang)).format(month);

  String _monthYear(DateTime month, String lang) =>
      DateFormat.yMMM(_intlLocale(lang)).format(month);
}

/// Card-shaped loading placeholders. No full-screen spinner is used.
class _ImpactLoadingView extends StatelessWidget {
  const _ImpactLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.padding),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 180, height: 28),
              SizedBox(height: 8),
              Skeleton(width: 260, height: 14),
            ],
          ),
        ),
        SizedBox(height: AppDimens.padding),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.padding),
          child: _SkeletonCard(
            child: Row(
              children: [
                Skeleton(width: 88, height: 88, radius: 44),
                SizedBox(width: AppDimens.padding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 140, height: 16),
                      SizedBox(height: 8),
                      Skeleton(width: 96, height: 12),
                      SizedBox(height: 8),
                      Skeleton(width: 150, height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: AppDimens.padding),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.padding),
          child: _SkeletonStatGrid(),
        ),
        SizedBox(height: AppDimens.padding),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.padding),
          child: Row(
            children: [
              Skeleton(width: 84, height: 40, radius: 20),
              SizedBox(width: 8),
              Skeleton(width: 84, height: 40, radius: 20),
            ],
          ),
        ),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimens.padding),
          child: _SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 160, height: 16),
                SizedBox(height: 8),
                Skeleton(width: 220, height: 12),
                SizedBox(height: AppDimens.padding),
                Skeleton(height: 220, radius: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonStatGrid extends StatelessWidget {
  const _SkeletonStatGrid();

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppDimens.gap,
        crossAxisSpacing: AppDimens.gap,
        mainAxisExtent: 140,
      ),
      children: const [
        _SkeletonStatCard(),
        _SkeletonStatCard(),
        _SkeletonStatCard(),
        _SkeletonStatCard(),
      ],
    );
  }
}

class _SkeletonStatCard extends StatelessWidget {
  const _SkeletonStatCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 32, height: 32, radius: 16),
            Spacer(),
            Skeleton(width: 80, height: 20),
            SizedBox(height: 6),
            Skeleton(width: 104, height: 12),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.padding),
        child: child,
      ),
    );
  }
}

String _intlLocale(String lang) => lang == 'en' ? 'en_US' : 'id_ID';
