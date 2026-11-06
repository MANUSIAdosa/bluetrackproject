import 'package:blue_track/features/donation/data/donation_flow_store.dart';
import 'package:blue_track/features/donation/presentation/donate_amount_page.dart';
import 'package:blue_track/shared/widgets/step_indicator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

void main() {
  setUp(() => DonationFlowStore.instance.clear());

  testWidgets('halaman nominal donasi tidak menampilkan StepIndicator', (
    tester,
  ) async {
    await tester.pumpWidget(wrapPage(const DonateAmountPage(projectId: 'p01')));
    await tester.pumpAndSettle();

    expect(find.byType(StepIndicator), findsNothing);
    expect(find.text('Donasi'), findsOneWidget);
    expect(find.text('Nominal cepat'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);
  });
}
