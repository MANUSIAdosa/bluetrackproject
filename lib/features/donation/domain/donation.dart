// Donation domain models for the P06 flow.
//
// The screen flow is: amount (Langkah 1) → confirmation (Langkah 3) → result.
// There is no separate purpose screen, so [DonationPurpose.project] is the
// default and is selected implicitly by the amount step.

/// How often the donation is charged.
enum DonationFrequency { once, monthly }

/// What the donation supports.
enum DonationPurpose { project, organization }

/// Mock payment channels offered on the confirmation step.
enum PaymentMethod { virtualAccount, eWallet, card }

/// Lifecycle of a donation payment.
enum DonationStatus { pending, success, failed }

/// Input captured before a donation exists.
///
/// [paymentMethod] stays nullable because it is chosen on the confirmation
/// step, after the amount step has already created the draft.
class DonationDraft {
  const DonationDraft({
    required this.projectId,
    required this.amount,
    required this.frequency,
    this.purpose = DonationPurpose.project,
    this.projectName = '',
    this.orgName = '',
    this.paymentMethod,
    this.showNameInReport = false,
  });

  final String projectId;
  final int amount;
  final DonationFrequency frequency;
  final DonationPurpose purpose;

  /// Filled by the confirmation step once the project has been loaded.
  final String projectName;

  /// Filled by the confirmation step once the project has been loaded.
  final String orgName;

  final PaymentMethod? paymentMethod;
  final bool showNameInReport;

  DonationDraft copyWith({
    String? projectId,
    int? amount,
    DonationFrequency? frequency,
    DonationPurpose? purpose,
    String? projectName,
    String? orgName,
    PaymentMethod? paymentMethod,
    bool? showNameInReport,
  }) {
    return DonationDraft(
      projectId: projectId ?? this.projectId,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      purpose: purpose ?? this.purpose,
      projectName: projectName ?? this.projectName,
      orgName: orgName ?? this.orgName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      showNameInReport: showNameInReport ?? this.showNameInReport,
    );
  }
}

/// A created (mock) donation, returned by `DonationRepository`.
class Donation {
  const Donation({
    required this.id,
    required this.amount,
    required this.frequency,
    required this.purpose,
    required this.paymentMethod,
    required this.showNameInReport,
    required this.projectId,
    required this.projectName,
    required this.orgName,
    required this.status,
    required this.receiptNumber,
    required this.createdAt,
  });

  final String id;
  final int amount;
  final DonationFrequency frequency;
  final DonationPurpose purpose;
  final PaymentMethod paymentMethod;
  final bool showNameInReport;
  final String projectId;
  final String projectName;
  final String orgName;
  final DonationStatus status;

  /// Public-facing reference, e.g. `BLU-20260312-0001`.
  final String receiptNumber;
  final DateTime createdAt;

  /// Rebuilds the input needed to retry this donation from the result screen.
  DonationDraft toDraft() {
    return DonationDraft(
      projectId: projectId,
      amount: amount,
      frequency: frequency,
      purpose: purpose,
      projectName: projectName,
      orgName: orgName,
      paymentMethod: paymentMethod,
      showNameInReport: showNameInReport,
    );
  }

  Donation copyWith({DonationStatus? status}) {
    return Donation(
      id: id,
      amount: amount,
      frequency: frequency,
      purpose: purpose,
      paymentMethod: paymentMethod,
      showNameInReport: showNameInReport,
      projectId: projectId,
      projectName: projectName,
      orgName: orgName,
      status: status ?? this.status,
      receiptNumber: receiptNumber,
      createdAt: createdAt,
    );
  }
}
