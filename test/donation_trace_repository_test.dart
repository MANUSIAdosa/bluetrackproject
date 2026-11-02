import 'package:blue_track/features/donation/domain/donation.dart';
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
    expect(
      donations.any((donation) => donation.status == DonationStatus.pending),
      isTrue,
    );
    expect(
      donations.any((donation) => donation.status == DonationStatus.failed),
      isTrue,
    );
  });

  test(
    'looks up a donation by id and returns null for an unknown id',
    () async {
      final repository = MockDonationTraceRepository();

      final donation = await repository.getById('don-1001');
      expect(donation, isNotNull);
      expect(donation!.projectId, 'p01');
      expect(donation.receiptNumber, 'BLU-20261012-0001');
      expect(donation.paymentMethod, PaymentMethod.virtualAccount);
      expect(donation.status, DonationStatus.success);
      expect(donation.steps.length, 4);
      expect(donation.stepFor(DonationTraceStepType.received), isNotNull);
      expect(donation.stepFor(DonationTraceStepType.fieldUpdate), isNotNull);

      expect(await repository.getById('don-tidak-ada'), isNull);
    },
  );

  test('parses the proof photo and description from the mock asset', () async {
    final repository = MockDonationTraceRepository();

    final donation = await repository.getById('don-1001');
    final proof = donation!.stepFor(DonationTraceStepType.proof);

    expect(proof, isNotNull);
    expect(proof!.photoAsset, 'assets/images/interests/marine_wildlife.jpg');
    expect(proof.description, contains('patroli pesisir'));
    expect(proof.hasPhoto, isTrue);
  });

  test('keeps pending and failed donations without milestones', () async {
    final repository = MockDonationTraceRepository();

    final pending = await repository.getById('don-1004');
    expect(pending!.status, DonationStatus.pending);
    expect(pending.steps, isEmpty);

    final failed = await repository.getById('don-1005');
    expect(failed!.status, DonationStatus.failed);
    expect(failed.steps, isEmpty);
  });
}
