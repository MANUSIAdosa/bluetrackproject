import '../../donation/domain/donation.dart';

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

  /// Value used in `assets/mock/donation_trace.json`.
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
  const DonationTraceStep({
    required this.type,
    required this.at,
    this.photoAsset,
    this.description,
  });

  final DonationTraceStepType type;
  final DateTime at;

  /// Optional proof photo, shown when the milestone is tapped.
  final String? photoAsset;

  /// Optional proof description, shown with [photoAsset].
  final String? description;

  /// Whether this milestone carries a photo that can be previewed.
  bool get hasPhoto => photoAsset != null && photoAsset!.isNotEmpty;
}

/// One mock donation and the milestones it has reached.
class DonationTrace {
  const DonationTrace({
    required this.id,
    required this.projectId,
    required this.projectTitle,
    required this.organization,
    required this.amount,
    required this.donatedAt,
    required this.receiptNumber,
    required this.paymentMethod,
    required this.status,
    required this.steps,
  });

  final String id;

  /// Project id used by the "Lihat laporan proyek" link.
  final String projectId;

  final String projectTitle;
  final String organization;
  final int amount;
  final DateTime donatedAt;

  /// Public-facing receipt reference, e.g. `BLU-20261012-0001`.
  final String receiptNumber;

  final PaymentMethod paymentMethod;
  final DonationStatus status;

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

      final photo = (row['photo'] as String?)?.trim();
      final description = (row['description'] as String?)?.trim();
      steps.add(
        DonationTraceStep(
          type: type,
          at: at,
          photoAsset: (photo == null || photo.isEmpty) ? null : photo,
          description: (description == null || description.isEmpty)
              ? null
              : description,
        ),
      );
    }

    return DonationTrace(
      id: json['id'] as String,
      projectId: json['projectId'] as String? ?? '',
      projectTitle: json['projectTitle'] as String,
      organization: json['organization'] as String,
      amount: (json['amount'] as num).toInt(),
      donatedAt: DateTime.parse(json['donatedAt'] as String),
      receiptNumber: json['receiptNumber'] as String? ?? json['id'] as String,
      paymentMethod: _paymentMethodFromJson(json['paymentMethod'] as String?),
      status: _statusFromJson(json['status'] as String?),
      steps: steps,
    );
  }

  static DonationStatus _statusFromJson(String? value) {
    return switch (value) {
      'success' => DonationStatus.success,
      'failed' => DonationStatus.failed,
      _ => DonationStatus.pending,
    };
  }

  static PaymentMethod _paymentMethodFromJson(String? value) {
    return switch (value) {
      'e_wallet' => PaymentMethod.eWallet,
      'card' => PaymentMethod.card,
      _ => PaymentMethod.virtualAccount,
    };
  }
}
