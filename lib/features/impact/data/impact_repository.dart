import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/impact_overview.dart';

/// Data source contract for P09 My Impact.
///
/// The UI only renders [ImpactOverview]: totals, the monthly goal and both
/// chart windows are computed here, so replacing the mock with an API client
/// later cannot change the numbers shown by the page.
abstract interface class ImpactRepository {
  Future<ImpactOverview> getOverview();
}

/// Mock implementation reading `assets/mock/impact.json`.
///
/// The asset holds 12 months and one `monthlyGoal`. The summary sums all
/// twelve months, the goal uses the latest row as its reference month, and
/// both chart windows are filtered here.
class MockImpactRepository implements ImpactRepository {
  const MockImpactRepository();

  static const _asset = 'assets/mock/impact.json';

  @override
  Future<ImpactOverview> getOverview() async {
    final raw = await rootBundle.loadString(_asset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rows = (decoded['months'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    final contributions = [
      for (final row in rows)
        ImpactContribution(
          month: DateTime.parse(row['month'] as String),
          reports: (row['reports'] as num).toInt(),
          actions: (row['actions'] as num).toInt(),
          wasteKg: (row['wasteKg'] as num).toDouble(),
          supportAmount: (row['supportAmount'] as num).toInt(),
        ),
    ]..sort((a, b) => a.month.compareTo(b.month));

    final summary = ImpactSummary(
      reports: contributions.fold(0, (sum, item) => sum + item.reports),
      actions: contributions.fold(0, (sum, item) => sum + item.actions),
      wasteKg: contributions.fold(0, (sum, item) => sum + item.wasteKg),
      supportAmount: contributions.fold(
        0,
        (sum, item) => sum + item.supportAmount,
      ),
    );

    final target = (decoded['monthlyGoal'] as num).toInt();
    final reference = contributions.isEmpty ? null : contributions.last;
    final completed = reference?.activityCount ?? 0;
    final progress = target <= 0
        ? 0.0
        : (completed / target).clamp(0.0, 1.0).toDouble();

    return ImpactOverview(
      summary: summary,
      goal: ImpactGoal(
        month: reference?.month,
        completed: completed,
        target: target,
        progress: progress,
      ),
      sixMonths: _latest(contributions, ImpactRange.sixMonths.months),
      twelveMonths: _latest(contributions, ImpactRange.oneYear.months),
    );
  }

  /// Keeps the newest [count] months, oldest first, for one chart window.
  List<ImpactContribution> _latest(
    List<ImpactContribution> contributions,
    int count,
  ) {
    final start = contributions.length > count
        ? contributions.length - count
        : 0;
    return List.unmodifiable(contributions.sublist(start));
  }
}
