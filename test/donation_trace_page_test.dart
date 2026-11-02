import 'package:blue_track/features/donation/domain/donation.dart';
import 'package:blue_track/features/support/data/donation_trace_repository.dart';
import 'package:blue_track/features/support/domain/donation_trace.dart';
import 'package:blue_track/features/support/presentation/donation_trace_page.dart';
import 'package:blue_track/shared/widgets/empty_state.dart';
import 'package:blue_track/shared/widgets/login_prompt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/test_harness.dart';

class FakeDonationTraceRepository implements DonationTraceRepository {
  FakeDonationTraceRepository({this.trace, this.error});

  DonationTrace? trace;
  Object? error;
  int calls = 0;

  @override
  Future<DonationTrace?> getById(String donationId) async {
    calls++;
    if (error != null) throw error!;
    return trace;
  }
}

DonationTrace traceWith(
  int completedSteps, {
  DonationStatus status = DonationStatus.success,
  bool proofPhoto = false,
  bool fieldUpdatePhoto = false,
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
    steps: [
      for (var i = 0; i < completedSteps; i++)
        _stepAt(i, proofPhoto: proofPhoto, fieldUpdatePhoto: fieldUpdatePhoto),
    ],
  );
}

DonationTraceStep _stepAt(
  int index, {
  required bool proofPhoto,
  required bool fieldUpdatePhoto,
}) {
  final type = DonationTraceStepType.values[index];
  final photo = switch (type) {
    DonationTraceStepType.proof =>
      proofPhoto ? 'assets/images/interests/marine_wildlife.jpg' : null,
    DonationTraceStepType.fieldUpdate =>
      fieldUpdatePhoto
          ? 'assets/images/interests/sustainable_fishery.jpg'
          : null,
    _ => null,
  };
  final description = switch (type) {
    DonationTraceStepType.proof =>
      proofPhoto ? 'Dokumentasi patroli sarang penyu.' : null,
    DonationTraceStepType.fieldUpdate =>
      fieldUpdatePhoto ? 'Pertemuan dengan nelayan setempat.' : null,
    _ => null,
  };

  return DonationTraceStep(
    type: type,
    at: DateTime(2026, 10, 12).add(Duration(days: index)),
    photoAsset: photo,
    description: description,
  );
}

Future<void> pumpTrace(
  WidgetTester tester,
  FakeDonationTraceRepository repository,
) async {
  await tester.pumpWidget(
    wrapPage(DonationTracePage(donationId: 'don-1001', repository: repository)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the donation and all four milestones without login', (
    tester,
  ) async {
    await pumpTrace(tester, FakeDonationTraceRepository(trace: traceWith(1)));

    expect(find.text('Jejak Dukungan'), findsOneWidget);
    final header = find.byKey(const ValueKey('p08-trace-header'));
    expect(header, findsOneWidget);
    expect(
      find.descendant(
        of: header,
        matching: find.text('Peneluruhan Penyu di Pantai Sukamade'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Yayasan Laut Biru')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Rp250.000')),
      findsOneWidget,
    );
    expect(find.text('Nomor donasi: don-1001'), findsOneWidget);
    expect(find.text('Perjalanan donasi'), findsOneWidget);

    // All four milestones stay visible; only the first one has happened.
    expect(find.text('Diterima'), findsOneWidget);
    expect(find.text('Diteruskan ke penyelenggara'), findsOneWidget);
    expect(find.text('Bukti'), findsOneWidget);
    expect(find.text('Update lapangan'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Public page: no login gate or prompt.
    expect(find.byType(LoginPromptCard), findsNothing);
  });

  testWidgets('marks all milestones when the trace is complete', (
    tester,
  ) async {
    await pumpTrace(tester, FakeDonationTraceRepository(trace: traceWith(4)));

    expect(find.byIcon(Icons.check), findsNWidgets(4));
  });

  testWidgets('explains a missing donation instead of failing silently', (
    tester,
  ) async {
    await pumpTrace(tester, FakeDonationTraceRepository(trace: null));

    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      find.text('Donasi tidak ditemukan. Periksa tautan atau coba lagi.'),
      findsOneWidget,
    );
  });

  testWidgets('offers a retry when the trace cannot be loaded', (tester) async {
    final repository = FakeDonationTraceRepository(
      trace: traceWith(1),
      error: StateError('offline'),
    );
    await pumpTrace(tester, repository);

    expect(
      find.text('Gagal memuat jejak donasi. Periksa koneksi lalu coba lagi.'),
      findsOneWidget,
    );

    repository.error = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Diterima'), findsOneWidget);
  });

  testWidgets('opens the proof preview from the Bukti milestone', (
    tester,
  ) async {
    await pumpTrace(
      tester,
      FakeDonationTraceRepository(trace: traceWith(3, proofPhoto: true)),
    );

    await tester.tap(find.text('Bukti'));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('p08-proof-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Pratinjau bukti')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Dokumentasi patroli sarang penyu.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('14 Oktober 2026')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('p08-proof-photo')), findsOneWidget);
  });

  testWidgets('opens the proof preview from a field update with a photo', (
    tester,
  ) async {
    await pumpTrace(
      tester,
      FakeDonationTraceRepository(trace: traceWith(4, fieldUpdatePhoto: true)),
    );

    await tester.ensureVisible(find.text('Update lapangan'));
    await tester.tap(find.text('Update lapangan'));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('p08-proof-sheet'));
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Pertemuan dengan nelayan setempat.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('15 Oktober 2026')),
      findsOneWidget,
    );
  });

  testWidgets('shows the E-Receipt card for a successful donation', (
    tester,
  ) async {
    await pumpTrace(tester, FakeDonationTraceRepository(trace: traceWith(1)));

    final card = find.byKey(const ValueKey('p08-receipt-card'));
    expect(card, findsOneWidget);
    expect(find.byKey(const ValueKey('p08-receipt-unavailable')), findsNothing);
    expect(
      find.descendant(of: card, matching: find.text('Nomor kwitansi')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('BLU-20261012-0001')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('12 Oktober 2026')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Rp250.000')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Peneluruhan Penyu di Pantai Sukamade'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Yayasan Laut Biru')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Transfer VA')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Berhasil')),
      findsOneWidget,
    );
  });

  testWidgets('explains that the E-Receipt is unavailable when pending', (
    tester,
  ) async {
    await pumpTrace(
      tester,
      FakeDonationTraceRepository(
        trace: traceWith(0, status: DonationStatus.pending),
      ),
    );

    expect(find.byKey(const ValueKey('p08-receipt-card')), findsNothing);
    final note = find.byKey(const ValueKey('p08-receipt-unavailable'));
    expect(note, findsOneWidget);
    expect(
      find.descendant(
        of: note,
        matching: find.text('E-Receipt belum tersedia'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: note,
        matching: find.text(
          'E-Receipt baru tersedia setelah dukungan berhasil.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: note, matching: find.text('Menunggu pembayaran')),
      findsOneWidget,
    );
  });

  testWidgets('explains that the E-Receipt is unavailable when failed', (
    tester,
  ) async {
    await pumpTrace(
      tester,
      FakeDonationTraceRepository(
        trace: traceWith(0, status: DonationStatus.failed),
      ),
    );

    expect(find.byKey(const ValueKey('p08-receipt-card')), findsNothing);
    final note = find.byKey(const ValueKey('p08-receipt-unavailable'));
    expect(note, findsOneWidget);
    expect(
      find.descendant(of: note, matching: find.text('Gagal')),
      findsOneWidget,
    );
  });

  testWidgets('opens the project reports tab from the trace page', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/support/trace/don-1001',
      routes: [
        GoRoute(
          path: '/support/trace/:donationId',
          builder: (context, state) => DonationTracePage(
            donationId: state.pathParameters['donationId']!,
            repository: FakeDonationTraceRepository(trace: traceWith(4)),
          ),
        ),
        GoRoute(
          path: '/project/:id',
          builder: (context, state) => Scaffold(
            body: Text(
              'project ${state.pathParameters['id']} '
              'tab=${state.uri.queryParameters['tab']}',
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('p08-view-reports')));
    await tester.tap(find.byKey(const ValueKey('p08-view-reports')));
    await tester.pumpAndSettle();

    expect(find.text('project p01 tab=reports'), findsOneWidget);
  });
}
