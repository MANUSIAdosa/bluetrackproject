/// Chart windows offered above the P09 contribution chart.
enum ImpactRange {
  sixMonths('6m', 6),
  oneYear('1y', 12);

  const ImpactRange(this.id, this.months);

  /// Stable id used by [FilterChipRow].
  final String id;

  /// Number of months this window shows.
  final int months;

  static ImpactRange? fromId(String id) {
    for (final range in values) {
      if (range.id == id) return range;
    }
    return null;
  }
}

/// One month of the signed-in user's contribution history.
class ImpactContribution {
  const ImpactContribution({
    required this.month,
    required this.reports,
    required this.actions,
    required this.wasteKg,
    required this.supportAmount,
  });

  /// First day of the month this row describes.
  final DateTime month;
  final int reports;
  final int actions;
  final double wasteKg;
  final int supportAmount;

  /// The bar height used by the monthly chart: reports plus joined actions.
  int get activityCount => reports + actions;
}

/// Totals across every month returned by the repository (12 in the mock).
class ImpactSummary {
  const ImpactSummary({
    required this.reports,
    required this.actions,
    required this.wasteKg,
    required this.supportAmount,
  });

  final int reports;
  final int actions;
  final double wasteKg;
  final int supportAmount;

  /// A user with no reports, actions, waste or support has nothing to show.
  bool get hasContributions =>
      reports > 0 || actions > 0 || wasteKg > 0 || supportAmount > 0;
}

/// Personal monthly goal for the reference month (the latest mock row).
class ImpactGoal {
  const ImpactGoal({
    required this.month,
    required this.completed,
    required this.target,
    required this.progress,
  });

  /// Reference month. Null only when the data set is empty.
  final DateTime? month;
  final int completed;
  final int target;

  /// 0.0–1.0, already clamped by the repository.
  final double progress;
}

/// Data the P09 page renders: lifetime totals, the monthly goal and both chart
/// windows.
class ImpactOverview {
  const ImpactOverview({
    required this.summary,
    required this.goal,
    required this.sixMonths,
    required this.twelveMonths,
  });

  final ImpactSummary summary;
  final ImpactGoal goal;

  /// Oldest month first; filtered by the repository, never by the widget.
  final List<ImpactContribution> sixMonths;
  final List<ImpactContribution> twelveMonths;

  /// A user with no contributions at all sees the empty state.
  bool get hasContributions => summary.hasContributions;

  List<ImpactContribution> chartFor(ImpactRange range) =>
      range == ImpactRange.oneYear ? twelveMonths : sixMonths;
}
