import 'dart:math';

import '../domain/data_failure.dart';

/// Lower bound of the simulated delay used by mock repositories.
const int kMockLatencyMinMs = 300;

/// Upper bound of the simulated delay used by mock repositories.
const int kMockLatencyMaxMs = 800;

/// The single mock "today" used by period filters and monthly trends.
///
/// Keeping this date in the data layer means the mock results do not depend on
/// the device clock. Repositories also accept an injected `referenceDate`.
final DateTime kMockReferenceDate = DateTime.utc(2026, 10, 24);

/// Applies the optional mock delay, then throws when [forceError] is true.
///
/// [latency] can be set to [Duration.zero] to disable the delay — tests must do
/// this so no timers are left pending. When [latency] is null a random delay
/// between [kMockLatencyMinMs] and [kMockLatencyMaxMs] milliseconds is used.
///
/// Throws [MockRepositoryException] after the delay when [forceError] is true.
///
/// ```dart
/// await simulateMockCall(latency: Duration.zero);
/// ```
Future<void> simulateMockCall({
  Duration? latency,
  bool forceError = false,
}) async {
  final delay =
      latency ??
      Duration(
        milliseconds:
            kMockLatencyMinMs +
            Random().nextInt(kMockLatencyMaxMs - kMockLatencyMinMs + 1),
      );
  if (delay > Duration.zero) {
    await Future<void>.delayed(delay);
  }
  if (forceError) {
    throw const MockRepositoryException();
  }
}
