import 'dart:convert';
import 'dart:io';

import 'package:blue_track/core/utils/formatters.dart';
import 'package:blue_track/features/explore/data/disbursement_repository.dart';
import 'package:blue_track/features/project/domain/data_failure.dart';
import 'package:blue_track/features/project/domain/disbursement.dart';
import 'package:blue_track/features/project/domain/report.dart';
import 'package:blue_track/features/project/presentation/widgets/p04_reports_tab.dart';
import 'package:blue_track/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/report_fixtures.dart';
import 'support/test_harness.dart';

/// Reads the bundled disbursement mock from disk, like the report fixtures do.
List<Disbursement> _mockDisbursements() {
  final raw = File('assets/mock/disbursements.json').readAsStringSync();
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded
      .map((item) => Disbursement.fromJson(item as Map<String, dynamic>))
      .toList(growable: false);
}

/// In-memory disbursement source with deterministic failure injection.
class _TestDisbursementRepository implements DisbursementRepository {
  _TestDisbursementRepository({this.failures = 0});

  /// Number of initial calls that fail, so the ErrorState can be exercised.
  int failures;

  int _calls = 0;

  static const _collected = <String, int>{
    'p01': 18750000,
    'p06': 4200000,
    'p08': 60000000,
  };

  Future<void> _maybeFail() async {
    if (_calls < failures) {
      _calls++;
      throw MockRepositoryException();
    }
  }

  @override
  Future<List<Disbursement>> getDisbursementsByLocation(
    String locationId, {
    DisbursementStatus? status,
  }) async {
    await _maybeFail();
    final entries =
        _mockDisbursements()
            .where((entry) => entry.locationId == locationId)
            .where((entry) => status == null || entry.status == status)
            .toList()
          ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    return entries;
  }

  @override
  Future<Disbursement> getDisbursementById(String id) async {
    await _maybeFail();
    return _mockDisbursements().firstWhere((entry) => entry.id == id);
  }

  @override
  Future<DisbursementSummary> getDisbursementSummary(String locationId) async {
    await _maybeFail();
    final collected = _collected[locationId] ?? 0;
    final disbursed =
        _mockDisbursements()
            .where((entry) => entry.locationId == locationId)
            .where((entry) => entry.status == DisbursementStatus.disalurkan)
            .fold<int>(0, (sum, entry) => sum + entry.amount);
    return DisbursementSummary(
      collected: collected,
      disbursed: disbursed,
      pending: collected - disbursed,
    );
  }
}

class _LedgerHost extends StatefulWidget {
  const _LedgerHost({
    required this.projectId,
    required this.disbursementRepository,
  });

  final String projectId;
  final DisbursementRepository disbursementRepository;

  @override
  State<_LedgerHost> createState() => _LedgerHostState();
}

class _LedgerHostState extends State<_LedgerHost> {
  @override
  Widget build(BuildContext context) {
    return P04ReportsTab(
      projectId: widget.projectId,
      locationName: 'Pantai Sukamade',
      repository: InMemoryReportRepository(),
      disbursementRepository: widget.disbursementRepository,
      initialSection: 'penyaluran',
      period: ReportPeriod.threeMonths,
      onPeriodChanged: (_) {},
    );
  }
}

Future<void> _pumpLedger(
  WidgetTester tester, {
  String projectId = 'p01',
  DisbursementRepository? repository,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(420, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    wrapPage(
      _LedgerHost(
        projectId: projectId,
        disbursementRepository: repository ?? _TestDisbursementRepository(),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

bool _chipSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P04 Penyaluran Dana', () {
    testWidgets('opens on the ledger with summary and newest-first entries', (
      tester,
    ) async {
      await _pumpLedger(tester, settle: false);
      await tester.pump();
      expect(find.byType(Skeleton), findsWidgets);

      await tester.pumpAndSettle();
      expect(_chipSelected(tester, 'Penyaluran Dana'), isTrue);
      expect(find.text('Dana terkumpul'), findsOneWidget);
      expect(find.text('Dana disalurkan'), findsOneWidget);
      expect(find.text('Belum disalurkan'), findsOneWidget);
      expect(
        find.text(Formatters.currency(18750000, 'id')),
        findsWidgets,
      );
      expect(find.text(Formatters.currency(10500000, 'id')), findsOneWidget);
      expect(find.text(Formatters.currency(8250000, 'id')), findsOneWidget);

      // The pending November entry is newest and therefore listed first.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('p04-disbursement-dis003'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('p04-disbursement-dis001'))).dy,
        ),
      );
      final scrollable = find
          .descendant(
            of: find.byKey(const PageStorageKey('p04-reports-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('p04-disbursement-dis002')),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('p04-disbursement-dis001'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('p04-disbursement-dis002'))).dy,
        ),
      );
      expect(find.text('Menunggu'), findsOneWidget);
      expect(find.text('Disalurkan'), findsWidgets);
    });

    testWidgets('switches to field conditions and back', (tester) async {
      await _pumpLedger(tester);
      expect(_chipSelected(tester, 'Penyaluran Dana'), isTrue);

      await tester.ensureVisible(find.text('Kondisi Lapangan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kondisi Lapangan'));
      await tester.pumpAndSettle();

      expect(_chipSelected(tester, 'Kondisi Lapangan'), isTrue);
      expect(find.text('Ringkasan kondisi'), findsOneWidget);

      await tester.ensureVisible(find.text('Penyaluran Dana'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Penyaluran Dana'));
      await tester.pumpAndSettle();
      expect(find.text('Dana terkumpul'), findsOneWidget);
    });

    testWidgets('opens the disbursement detail sheet and closes it', (
      tester,
    ) async {
      await _pumpLedger(tester);
      await tester.tap(find.byKey(const ValueKey('p04-disbursement-dis001')));
      await tester.pumpAndSettle();

      expect(find.text('Detail Penyaluran'), findsOneWidget);
      expect(find.text(Formatters.currency(6000000, 'id')), findsWidgets);
      expect(find.textContaining('Yayasan Laut Biru'), findsWidgets);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Penyaluran'), findsNothing);
    });

    testWidgets('shows the empty state for a location without disbursements', (
      tester,
    ) async {
      await _pumpLedger(tester, projectId: 'p02');

      expect(find.text('Belum ada penyaluran dana.'), findsOneWidget);
      expect(find.byKey(const ValueKey('p04-disbursement-dis001')), findsNothing);
    });

    testWidgets('shows an error state and retries successfully', (tester) async {
      await _pumpLedger(
        tester,
        repository: _TestDisbursementRepository(failures: 2),
      );

      expect(find.text('Gagal memuat. Periksa koneksi Anda.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);

      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Dana terkumpul'), findsOneWidget);
      expect(find.byKey(const ValueKey('p04-disbursement-dis001')), findsOneWidget);
    });
  });
}
