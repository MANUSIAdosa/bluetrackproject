import 'package:blue_track/features/donation/domain/donation.dart';
import 'package:blue_track/features/support/data/donation_trace_repository.dart';
import 'package:blue_track/features/support/domain/donation_trace.dart';
import 'package:blue_track/features/support/presentation/donation_trace_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

class _Repo implements DonationTraceRepository {
  _Repo(this.trace);

  final DonationTrace trace;

  @override
  Future<DonationTrace?> getById(String donationId) async => trace;
}

DonationTrace _trace({
  DonationStatus status = DonationStatus.success,
  List<DonationTraceStep>? steps,
}) {
  return DonationTrace(
    id: 'don-1001',
    projectId: 'p01',
    projectTitle: 'Peneluruhan Penyu di Pantai Sukamade',
    organization: 'Yayasan Laut Biru',
    amount: 250000,
    donatedAt: DateTime(2026, 10, 12),
    receiptNumber: 'BLU-20261012-0001',
    paymentMethod: PaymentMethod.virtualAccount,
    status: status,
    steps:
        steps ??
        [
          DonationTraceStep(
            type: DonationTraceStepType.received,
            at: DateTime(2026, 10, 12),
          ),
          DonationTraceStep(
            type: DonationTraceStepType.forwarded,
            at: DateTime(2026, 10, 13),
          ),
          DonationTraceStep(
            type: DonationTraceStepType.proof,
            at: DateTime(2026, 10, 14),
          ),
          DonationTraceStep(
            type: DonationTraceStepType.fieldUpdate,
            at: DateTime(2026, 10, 15),
          ),
        ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  DonationTrace trace, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    wrapPage(
      DonationTracePage(donationId: 'don-1001', repository: _Repo(trace)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await loader.load();
  });

  testWidgets('P08 visual check', (tester) async {
    await _pump(tester, _trace(), size: const Size(390, 1500));

    await expectLater(
      find.byType(DonationTracePage),
      matchesGoldenFile('goldens/p08_visual.png'),
    );
  });

  testWidgets('P08 pending visual check', (tester) async {
    await _pump(
      tester,
      _trace(status: DonationStatus.pending, steps: const []),
      size: const Size(320, 900),
    );

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(DonationTracePage),
      matchesGoldenFile('goldens/p08_pending_visual.png'),
    );
  });
}
