import 'package:flutter/foundation.dart';

import '../domain/donation.dart';
import '../domain/donation_rules.dart';
import 'mock_payment_config.dart';

/// Data source contract for donations (P06).
///
/// Swap the mock with an API implementation later without touching the UI.
abstract interface class DonationRepository {
  Future<Donation> createDonation(DonationDraft draft);

  /// Returns the latest record so the result screen can refresh its status.
  Future<Donation?> getDonationStatus(String donationId);
}

/// Data source contract for the mock payment gateway.
abstract interface class PaymentRepository {
  Future<DonationStatus> processPayment(String donationId);
}

/// In-memory store shared by both mocks, so a status refresh sees the latest
/// record. TODO(mock): replace with Hive when persistence across restarts is
/// required.
abstract final class DonationMemoryStore {
  static final Map<String, Donation> _donations = {};
  static int _sequence = 0;
  static String? _receiptDay;
  static int _receiptSequence = 0;

  static Donation create({
    required DonationDraft draft,
    required String projectName,
    required String orgName,
  }) {
    final now = DateTime.now();
    _sequence++;
    final donation = Donation(
      id: 'don_${now.microsecondsSinceEpoch}_$_sequence',
      amount: draft.amount,
      frequency: draft.frequency,
      purpose: draft.purpose,
      paymentMethod: draft.paymentMethod!,
      showNameInReport: draft.showNameInReport,
      projectId: draft.projectId,
      projectName: projectName,
      orgName: orgName,
      status: DonationStatus.pending,
      receiptNumber: _nextReceiptNumber(now),
      createdAt: now,
    );
    _donations[donation.id] = donation;
    return donation;
  }

  static Donation? get(String id) => _donations[id];

  static Donation? updateStatus(String id, DonationStatus status) {
    final donation = _donations[id];
    if (donation == null) return null;
    final updated = donation.copyWith(status: status);
    _donations[id] = updated;
    return updated;
  }

  static String _nextReceiptNumber(DateTime now) {
    final day = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    if (_receiptDay != day) {
      _receiptDay = day;
      _receiptSequence = 0;
    }
    _receiptSequence++;
    return 'BLU-$day-${_receiptSequence.toString().padLeft(4, '0')}';
  }

  /// Clears the mock store between test cases.
  @visibleForTesting
  static void reset() {
    _donations.clear();
    _sequence = 0;
    _receiptDay = null;
    _receiptSequence = 0;
  }
}

/// Mock donation repository backed by [DonationMemoryStore].
class MockDonationRepository implements DonationRepository {
  const MockDonationRepository();

  @override
  Future<Donation> createDonation(DonationDraft draft) async {
    if (draft.paymentMethod == null) {
      throw ArgumentError('A payment method is required.');
    }
    if (draft.amount < DonationRules.minAmount) {
      throw ArgumentError('Donation amount is below the minimum.');
    }
    if (draft.projectName.isEmpty) {
      throw ArgumentError('A project name is required.');
    }

    // Simulates the round-trip that shows the in-button loading state.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return DonationMemoryStore.create(
      draft: draft,
      projectName: draft.projectName,
      orgName: draft.orgName,
    );
  }

  @override
  Future<Donation?> getDonationStatus(String donationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return DonationMemoryStore.get(donationId);
  }
}

/// Mock payment gateway with deterministic outcomes.
class MockPaymentRepository implements PaymentRepository {
  const MockPaymentRepository();

  @override
  Future<DonationStatus> processPayment(String donationId) async {
    final donation = DonationMemoryStore.get(donationId);
    if (donation == null) {
      throw StateError('Unknown donation: $donationId');
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));
    final status = MockPaymentConfig.outcomeFor(donation.amount);
    DonationMemoryStore.updateStatus(donationId, status);
    return status;
  }
}

/// Feature-local registry.
///
/// TODO(registry): mirror these entries in `features/repositories.dart` once
/// the shared registry owner allows changes outside `features/donation`.
abstract final class DonationRepositories {
  static const DonationRepository donations = MockDonationRepository();
  static const PaymentRepository payments = MockPaymentRepository();
}
