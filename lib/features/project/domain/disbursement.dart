/// A fund disbursement (penyaluran dana) for one monitored location.
/// An entry records one money movement against a funding line: how much was
/// paid, when, who executed it and whether it reached the field. The mock source
/// lives in `assets/mock/disbursements.json`.
class Disbursement {
  const Disbursement({
    required this.id,
    required this.locationId,
    required this.category,
    required this.amount,
    required this.status,
    required this.dueDate,
    required this.executor,
    required this.proofPhoto,
  });

  /// Unique disbursement id, for example `dis001`.
  final String id;

  /// Id of the `ProjectLocation` this disbursement belongs to.
  final String locationId;

  /// Funding line the money was or will be paid against, for example
  /// `Patroli dan penjagaan sarang`.
  final String category;

  /// Disbursed amount in IDR.
  final int amount;

  /// Whether the money reached the field (`disalurkan`) or is still waiting
  /// (`menunggu`).
  final DisbursementStatus status;

  /// When the money was disbursed or is scheduled to be disbursed, in UTC.
  final DateTime dueDate;

  /// Organisation or field executor that handled the disbursement.
  final String executor;

  /// Local asset path proving the field activity, for example a report photo.
  final String proofPhoto;

  /// Parses one disbursement object from `assets/mock/disbursements.json`.
  ///
  /// Throws a [FormatException] when a required key is missing or has the
  /// wrong type.
  factory Disbursement.fromJson(Map<String, dynamic> json) => Disbursement(
    id: json['id'] as String,
    locationId: json['locationId'] as String,
    category: json['category'] as String,
    amount: (json['amount'] as num).toInt(),
    status: DisbursementStatus.fromId(json['status'] as String),
    dueDate: DateTime.parse(json['dueDate'] as String).toUtc(),
    executor: json['executor'] as String,
    proofPhoto: json['proofPhoto'] as String,
  );

  /// Serializes this disbursement back to the mock JSON shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'locationId': locationId,
    'category': category,
    'amount': amount,
    'status': status.id,
    'dueDate': dueDate.toUtc().toIso8601String(),
    'executor': executor,
    'proofPhoto': proofPhoto,
  };
}

/// Lifecycle of one fund disbursement.
enum DisbursementStatus {
  /// Money reached the field activity.
  disalurkan('disalurkan'),

  /// Money is still waiting to be disbursed.
  menunggu('menunggu');

  const DisbursementStatus(this.id);

  /// Value stored in JSON and exposed to the UI.
  final String id;

  /// Parses a status id. Throws a [FormatException] for unknown ids.
  static DisbursementStatus fromId(String id) => values.firstWhere(
    (value) => value.id == id,
    orElse: () => throw FormatException('Unknown disbursement status: $id'),
  );
}

/// Money movement totals for one location.
///
/// [collected] is what donors raised for the location, [disbursed] is what was
/// handed to the field and [pending] is what is left before it is disbursed.
class DisbursementSummary {
  const DisbursementSummary({
    required this.collected,
    required this.disbursed,
    required this.pending,
  });

  /// Funds raised for the location (the project target minus what is left).
  final int collected;

  /// Funds actually disbursed to field activities.
  final int disbursed;

  /// Funds raised but not disbursed yet.
  final int pending;
}

