import '../domain/donation.dart';

/// Deterministic mock payment outcomes, for manual checks and tests.
///
/// Default rule, documented for QA:
/// - amount ending in `1` → [DonationStatus.failed]  (e.g. Rp100.001)
/// - amount ending in `2` → [DonationStatus.pending] (e.g. Rp100.002)
/// - every other amount → [DonationStatus.success]
///
/// Set [forcedOutcome] to bypass the rule (tests); call [reset] afterwards.
abstract final class MockPaymentConfig {
  static DonationStatus? forcedOutcome;

  static DonationStatus outcomeFor(int amount) {
    final forced = forcedOutcome;
    if (forced != null) return forced;
    switch (amount % 10) {
      case 1:
        return DonationStatus.failed;
      case 2:
        return DonationStatus.pending;
      default:
        return DonationStatus.success;
    }
  }

  static void reset() => forcedOutcome = null;
}
