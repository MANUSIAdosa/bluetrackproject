import 'package:blue_track/features/support/data/donation_trace_repository.dart';
import 'package:blue_track/features/support/domain/donation_trace.dart';
import 'package:blue_track/features/support/presentation/donation_trace_page.dart';
import 'package:blue_track/shared/widgets/empty_state.dart';
import 'package:blue_track/shared/widgets/login_prompt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

DonationTrace traceWith(int completedSteps) {
  return DonationTrace(
    id: 'don-1001',
    projectTitle: 'Peneluruhan Penyu di Pantai Sukamade',
    organization: 'Yayasan Laut Biru',
    amount: 250000,
    donatedAt: DateTime(2026, 10, 12),
    steps: [
      for (var i = 0; i < completedSteps; i++)
        DonationTraceStep(
          type: DonationTraceStepType.values[i],
          at: DateTime(2026, 10, 12).add(Duration(days: i)),
        ),
    ],
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
    expect(find.text('Peneluruhan Penyu di Pantai Sukamade'), findsOneWidget);
    expect(find.text('Yayasan Laut Biru'), findsOneWidget);
    expect(find.text('Rp250.000'), findsOneWidget);
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
}
