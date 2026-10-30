import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/report.dart';
import '../p04_format.dart';
import '../p04_report_visuals.dart';

/// Monthly condition trend for the P04 Reports tab.
///
/// The widget only draws the points the repository already aggregated: it never
/// averages severities or filters reports itself. The y-axis is fixed to the
/// three severity scores (1–3), so the same scale is used for every period.
class P04ConditionChart extends StatelessWidget {
  const P04ConditionChart({super.key, required this.points});

  /// Oldest month first, as returned by the repository.
  final List<MonthlyConditionPoint> points;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('p04_chart_title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('p04_chart_subtitle'),
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.gap),
            if (points.length < 2)
              SizedBox(
                height: 220,
                child: EmptyState(
                  key: const ValueKey('p04-chart-empty'),
                  icon: Icons.show_chart,
                  message: context.tr('p04_chart_empty'),
                ),
              )
            else ...[
              SizedBox(
                key: const ValueKey('p04-condition-chart'),
                height: 220,
                child: LineChart(
                  _chartData(context, lang),
                  duration: const Duration(milliseconds: 240),
                ),
              ),
              const SizedBox(height: AppDimens.gap),
              Row(
                children: [
                  const Icon(
                    Icons.trending_down,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.tr('p04_chart_hint'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  LineChartData _chartData(BuildContext context, String lang) {
    return LineChartData(
      minX: 0,
      maxX: (points.length - 1).toDouble(),
      minY: 1,
      maxY: 3,
      // Dots at 1 and 3 sit exactly on the bounds, so do not clip them.
      clipData: const FlClipData.none(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
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
            interval: 1,
            reservedSize: 58,
            getTitlesWidget: (value, meta) {
              final label = switch (value.round()) {
                1 => context.p04SeverityLabel(ReportSeverity.low),
                2 => context.p04SeverityLabel(ReportSeverity.medium),
                3 => context.p04SeverityLabel(ReportSeverity.high),
                _ => '',
              };
              if (label.isEmpty) return const SizedBox.shrink();
              return SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(
                  label,
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
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= points.length) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(
                  P04Format.monthShort(points[index].month, lang),
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
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.oceanDeep,
          tooltipBorderRadius: BorderRadius.circular(8),
          getTooltipItems: (spots) => spots.map((spot) {
            final index = spot.x.round().clamp(0, points.length - 1).toInt();
            final point = points[index];
            return LineTooltipItem(
              context.tr('p04_chart_tooltip', {
                'month': P04Format.monthYear(point.month, lang),
                'value': P04Format.number(point.averageScore, lang),
                'n': P04Format.integer(point.reportCount, lang),
              }),
              const TextStyle(
                color: AppColors.surface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < points.length; i++)
              FlSpot(i.toDouble(), points[i].averageScore),
          ],
          isCurved: false,
          color: AppColors.ocean,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.ocean,
                  strokeWidth: 2,
                  strokeColor: AppColors.surface,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.ocean.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}
