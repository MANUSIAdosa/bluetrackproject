import 'package:blue_track/core/router/routes.dart';
import 'package:blue_track/features/donation/data/donation_repositories.dart';
import 'package:blue_track/features/donation/domain/donation.dart';
import 'package:blue_track/features/donation/presentation/donate_status_page.dart';
import 'package:blue_track/features/support/presentation/donation_trace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/test_harness.dart';

void main() {
  testWidgets(
    'P06 success button opens the real P08 trace for the created donation',
    (tester) async {
      addTearDown(DonationMemoryStore.reset);

      final donation = DonationMemoryStore.create(
        draft: const DonationDraft(
          projectId: 'p01',
          amount: 100000,
          frequency: DonationFrequency.once,
          projectName: 'Peneluruhan Penyu di Pantai Sukamade',
          orgName: 'Yayasan Laut Biru',
          paymentMethod: PaymentMethod.virtualAccount,
        ),
        projectName: 'Peneluruhan Penyu di Pantai Sukamade',
        orgName: 'Yayasan Laut Biru',
      );
      DonationMemoryStore.updateStatus(donation.id, DonationStatus.success);

      final router = GoRouter(
        initialLocation: Routes.donationStatusUrl(donation.id),
        routes: [
          GoRoute(
            path: Routes.donationStatus,
            builder: (context, state) => DonateStatusPage(
              donationId: state.pathParameters['donationId']!,
            ),
          ),
          GoRoute(
            path: Routes.donationTrace,
            builder: (context, state) => DonationTracePage(
              donationId: state.pathParameters['donationId']!,
            ),
          ),
        ],
      );

      await tester.pumpWidget(wrapRouter(router));
      await tester.pumpAndSettle();

      expect(find.text('Lihat Jejak dan E-Receipt'), findsOneWidget);

      await tester.tap(find.text('Lihat Jejak dan E-Receipt'));
      await tester.pumpAndSettle();

      expect(find.byType(DonationTracePage), findsOneWidget);
      expect(find.text('Jejak Dukungan'), findsOneWidget);
      expect(
        find.text('Donasi tidak ditemukan. Periksa tautan atau coba lagi.'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('p08-receipt-card')), findsOneWidget);
      expect(find.text(donation.receiptNumber), findsOneWidget);
      expect(find.text('Diterima'), findsOneWidget);
      expect(find.text('Diteruskan ke penyelenggara'), findsOneWidget);
    },
  );
}
