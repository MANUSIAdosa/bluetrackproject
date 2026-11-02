/// The four public milestones of a donation.
///
/// Declaration order is the order shown on the trace page; pending milestones
/// are still rendered, just in gray.
enum DonationTraceStepType {
  received('received'),
  forwarded('forwarded'),
  proof('proof'),
  fieldUpdate('field_update');

  const DonationTraceStepType(this.jsonValue);

  /// Value used in `assets/mock/donations.json`.
  final String jsonValue;

  static DonationTraceStepType? fromJson(String? value) {
    for (final type in values) {
      if (type.jsonValue == value) return type;
    }
    return null;
  }
}

/// One milestone that has actually happened.
class DonationTraceStep {
  const DonationTraceStep({required this.type, required this.at});

  final DonationTraceStepType type;
  final DateTime at;
}

/// One mock donation and the milestones it has reached.
class DonationTrace {
  const DonationTrace({
    required this.id,
    required this.projectTitle,
    required this.organization,
    required this.amount,
    required this.donatedAt,
    required this.steps,
  });

  final String id;
  final String projectTitle;
  final String organization;
  final int amount;
  final DateTime donatedAt;

  /// Only the milestones that have occurred; absent ones are still shown as
  /// pending by the page.
  final List<DonationTraceStep> steps;

  DonationTraceStep? stepFor(DonationTraceStepType type) {
    for (final step in steps) {
      if (step.type == type) return step;
    }
    return null;
  }

  factory DonationTrace.fromJson(Map<String, dynamic> json) {
    final steps = <DonationTraceStep>[];
    for (final raw in (json['steps'] as List<dynamic>? ?? const [])) {
      final row = raw as Map<String, dynamic>;
      final type = DonationTraceStepType.fromJson(row['type'] as String?);
      final at = DateTime.tryParse(row['at'] as String? ?? '');
      if (type == null || at == null) continue;
      steps.add(DonationTraceStep(type: type, at: at));
    }

    return DonationTrace(
      id: json['id'] as String,
      projectTitle: json['projectTitle'] as String,
      organization: json['organization'] as String,
      amount: (json['amount'] as num).toInt(),
      donatedAt: DateTime.parse(json['donatedAt'] as String),
      steps: steps,
    );
  }
}
