import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/donation_trace.dart';

/// Data source contract for P08 donation traces.
///
/// The trace is public: no login or donation ownership check happens here.
abstract interface class DonationTraceRepository {
  /// Returns the trace for [donationId], or null when the mock has no match.
  Future<DonationTrace?> getById(String donationId);
}

/// Mock implementation reading `assets/mock/donation_trace.json`.
class MockDonationTraceRepository implements DonationTraceRepository {
  MockDonationTraceRepository();

  /// In-memory seed for tests and previews, so no asset IO is required.
  MockDonationTraceRepository.withDonations(List<DonationTrace> donations)
    : _donations = List.of(donations);

  static const _asset = 'assets/mock/donation_trace.json';

  List<DonationTrace>? _donations;

  Future<List<DonationTrace>> _ensureLoaded() async {
    if (_donations != null) return _donations!;
    _donations = await loadFromAsset();
    return _donations!;
  }

  @override
  Future<DonationTrace?> getById(String donationId) async {
    final donations = await _ensureLoaded();
    for (final donation in donations) {
      if (donation.id == donationId) return donation;
    }
    return null;
  }

  /// Reads the asset directly — used by tests to verify the mock contract.
  static Future<List<DonationTrace>> loadFromAsset() async {
    final raw = await rootBundle.loadString(_asset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rows = decoded['donations'] as List<dynamic>? ?? const [];

    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        DonationTrace.fromJson(row),
    ];
  }
}
