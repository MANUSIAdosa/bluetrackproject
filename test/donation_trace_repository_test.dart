import 'package:blue_track/features/support/data/donation_trace_repository.dart';
import 'package:blue_track/features/support/domain/donation_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mock asset contains a complete and a one-step donation', () async {
    final donations = await MockDonationTraceRepository.loadFromAsset();

    expect(donations.length, greaterThanOrEqualTo(2));
    expect(donations.any((donation) => donation.steps.length == 4), isTrue);
    expect(donations.any((donation) => donation.steps.length == 1), isTrue);
  });

  test(
    'looks up a donation by id and returns null for an unknown id',
    () async {
      final repository = MockDonationTraceRepository();

      final donation = await repository.getById('don-1001');
      expect(donation, isNotNull);
      expect(donation!.steps.length, 4);
      expect(donation.stepFor(DonationTraceStepType.received), isNotNull);
      expect(donation.stepFor(DonationTraceStepType.fieldUpdate), isNotNull);

      expect(await repository.getById('don-tidak-ada'), isNull);
    },
  );
}
