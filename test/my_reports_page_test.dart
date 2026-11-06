import 'dart:async';
import 'dart:typed_data';

import 'package:blue_track/core/router/routes.dart';
import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/my_reports/data/my_reports_store.dart';
import 'package:blue_track/features/my_reports/presentation/my_reports_page.dart';
import 'package:blue_track/features/project/data/report_repository.dart';
import 'package:blue_track/features/project/domain/report.dart';
import 'package:blue_track/features/project/presentation/p04_format.dart';
import 'package:blue_track/shared/widgets/login_prompt_card.dart';
import 'package:blue_track/shared/widgets/zoomable_photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/report_fixtures.dart';
import 'support/test_harness.dart';

/// One pixel of transparent PNG — keeps the map tile layer off the network.
final _transparentPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _FakeTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentPng);
}

class _ControlledRepository extends InMemoryReportRepository {
  final completer = Completer<List<Report>>();

  @override
  Future<List<Report>> getReportsByUser(
    String userId, {
    ReportStatus? status,
  }) => completer.future;
}

class _FlakyRepository extends InMemoryReportRepository {
  int failuresRemaining = 1;

  @override
  Future<List<Report>> getReportsByUser(
    String userId, {
    ReportStatus? status,
  }) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('offline');
    }
    return super.getReportsByUser(userId, status: status);
  }
}

/// Returns nothing on the first load, then the full fixture after the report
/// form is popped — the page must reload after creating a report.
class _RevealAfterReturnRepository extends InMemoryReportRepository {
  int calls = 0;

  @override
  Future<List<Report>> getReportsByUser(
    String userId, {
    ReportStatus? status,
  }) async {
    calls++;
    if (calls == 1) return const [];
    return super.getReportsByUser(userId, status: status);
  }
}

Report _report(String id) =>
    mockReports().firstWhere((report) => report.id == id);

Future<void> _signIn() async {
  FlutterSecureStorage.setMockInitialValues({});
  await AuthController.instance.signIn('tester@example.com');
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required ReportRepository repository,
  Size size = const Size(390, 900),
  TileProvider? tileProvider,
  bool settle = true,
  Locale locale = const Locale('id'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    wrapPage(
      MyReportsPage(repository: repository, mapTileProvider: tileProvider),
      locale: locale,
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _pumpRouter(
  WidgetTester tester,
  GoRouter router, {
  Size size = const Size(390, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(wrapRouter(router));
  await tester.pumpAndSettle();
}

Future<void> _filterBy(WidgetTester tester, String statusId) async {
  await tester.tap(find.byKey(const ValueKey('my-reports-filter-button')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(ValueKey('my-reports-filter-option-$statusId')),
  );
  await tester.pumpAndSettle();
}

/// The related-action row is the last item of the sheet, below the fold on a
/// phone-sized surface, so these tests scroll it into view first.
Future<void> _scrollToActions(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('my-report-open-actions')),
    280,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('my-report-sheet-scroll')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    MyReportsStore.instance.reset();
  });

  tearDown(() async {
    await AuthController.instance.signOut();
  });

  testWidgets('signed-out users see the login prompt instead of reports', (
    tester,
  ) async {
    await _pumpPage(tester, repository: InMemoryReportRepository());

    expect(find.byType(LoginPromptCard), findsOneWidget);
    expect(find.text('Fitur ini butuh masuk'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('my-reports-filter-button')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('my-reports-list')), findsNothing);
  });

  testWidgets('signing in loads the reports without leaving the page', (
    tester,
  ) async {
    await _pumpPage(tester, repository: InMemoryReportRepository());
    expect(find.byType(LoginPromptCard), findsOneWidget);

    await _signIn();
    await tester.pumpAndSettle();

    expect(find.byType(LoginPromptCard), findsNothing);
    expect(find.byKey(const ValueKey('my-report-r006')), findsOneWidget);
  });

  testWidgets('lists reports with category, title, date, status and severity', (
    tester,
  ) async {
    await _signIn();
    await _pumpPage(tester, repository: InMemoryReportRepository());

    expect(find.text('Laporan Saya'), findsOneWidget);
    expect(find.text('5 laporan'), findsOneWidget);
    final filterButton = find.byKey(
      const ValueKey('my-reports-filter-button'),
    );
    expect(filterButton, findsOneWidget);
    await tester.tap(filterButton);
    await tester.pumpAndSettle();

    for (final entry in {
      'all': 'Semua',
      'terkirim': 'Terkirim',
      'diverifikasi': 'Diverifikasi',
      'ditindaklanjuti': 'Ditindaklanjuti',
      'selesai': 'Selesai',
    }.entries) {
      final option = find.byKey(
        ValueKey('my-reports-filter-option-${entry.key}'),
      );
      expect(option, findsOneWidget);
      expect(
        find.descendant(
          of: option,
          matching: find.textContaining(entry.value),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('Selesai (2)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('my-reports-filter-close')));
    await tester.pumpAndSettle();

    final report = _report('r006');
    final card = find.byKey(const ValueKey('my-report-r006'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Sampah laut')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Serpihan styrofoam di sepanjang garis pantai'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text(P04Format.date(report.reportedAt.toLocal(), 'id')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Diverifikasi')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Tingkat: Ringan')),
      findsOneWidget,
    );

    expect(find.byKey(const ValueKey('my-report-r019')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-report-r023')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-report-r013')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-report-r001')), findsOneWidget);
  });

  testWidgets('uses the English P04 labels when the app is in English', (
    tester,
  ) async {
    await _signIn();
    await _pumpPage(
      tester,
      repository: InMemoryReportRepository(),
      locale: const Locale('en'),
    );

    expect(find.text('My Reports'), findsOneWidget);
    expect(find.text('5 reports'), findsOneWidget);
    final card = find.byKey(const ValueKey('my-report-r006'));
    expect(
      find.descendant(of: card, matching: find.text('Marine debris')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Verified')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Severity: Low')),
      findsOneWidget,
    );
  });

  testWidgets('lays out without overflow on a small phone', (tester) async {
    await _signIn();
    await _pumpPage(
      tester,
      repository: InMemoryReportRepository(),
      size: const Size(320, 900),
      tileProvider: _FakeTileProvider(),
    );

    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('my-report-r006')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the filter menu narrows the list by status', (tester) async {
    await _signIn();
    await _pumpPage(tester, repository: InMemoryReportRepository());

    await _filterBy(tester, 'selesai');

    expect(find.byKey(const ValueKey('my-report-r001')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-report-r023')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-report-r006')), findsNothing);
    expect(find.byKey(const ValueKey('my-report-r013')), findsNothing);
    expect(find.byKey(const ValueKey('my-report-r019')), findsNothing);
    expect(find.text('Selesai · 2 laporan'), findsOneWidget);

    await _filterBy(tester, 'terkirim');

    expect(find.byKey(const ValueKey('my-report-r019')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-report-r001')), findsNothing);
    expect(find.text('Terkirim · 1 laporan'), findsOneWidget);
  });

  testWidgets(
    'an empty status filter explains itself without inviting a report',
    (tester) async {
      await _signIn();
      await _pumpPage(
        tester,
        repository: InMemoryReportRepository(reports: [_report('r019')]),
      );

      await _filterBy(tester, 'diverifikasi');

      expect(
        find.text('Tidak ada laporan berstatus Diverifikasi.'),
        findsOneWidget,
      );
      expect(find.text('Buat laporan'), findsNothing);
      expect(
        find.byKey(const ValueKey('my-reports-create')),
        findsNothing,
      );
      expect(find.text('Tampilkan semua'), findsOneWidget);
      expect(find.byKey(const ValueKey('my-report-r019')), findsNothing);

      // The recovery action clears the filter without inviting a report.
      await tester.tap(find.text('Tampilkan semua'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('my-report-r019')), findsOneWidget);
    },
  );

  testWidgets('keeps a create-report button while reports exist', (
    tester,
  ) async {
    await _signIn();
    final router = GoRouter(
      initialLocation: Routes.myReports,
      routes: [
        GoRoute(
          path: Routes.myReports,
          builder: (context, state) => MyReportsPage(
            repository: InMemoryReportRepository(),
            mapTileProvider: _FakeTileProvider(),
          ),
        ),
        GoRoute(
          path: Routes.report,
          builder: (context, state) =>
              Scaffold(appBar: AppBar(), body: const Text('report-form')),
        ),
      ],
    );

    await _pumpRouter(tester, router, size: const Size(390, 900));

    final create = find.byKey(const ValueKey('my-reports-create'));
    expect(create, findsOneWidget);
    expect(find.text('Buat laporan'), findsOneWidget);

    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('report-form'), findsOneWidget);
  });

  testWidgets('a user without any reports is invited to create one', (
    tester,
  ) async {
    await _signIn();
    await _pumpPage(
      tester,
      repository: InMemoryReportRepository(reports: const []),
    );

    expect(find.text('Belum ada laporan'), findsOneWidget);
    expect(find.textContaining('Laporkan temuan di sekitarmu'), findsOneWidget);
    expect(find.text('Buat laporan'), findsOneWidget);
    // The empty state button is the only create affordance. The filter menu
    // remains available with zero counts, without a duplicate FAB.
    expect(find.byKey(const ValueKey('my-reports-create')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('my-reports-filter-button')));
    await tester.pumpAndSettle();
    expect(find.text('Selesai (0)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('my-reports-filter-close')));
    await tester.pumpAndSettle();
  });

  testWidgets('the create-report action opens the report form', (tester) async {
    await _signIn();
    final router = GoRouter(
      initialLocation: Routes.myReports,
      routes: [
        GoRoute(
          path: Routes.myReports,
          builder: (context, state) => MyReportsPage(
            repository: InMemoryReportRepository(reports: const []),
          ),
        ),
        GoRoute(
          path: Routes.report,
          builder: (context, state) =>
              Scaffold(appBar: AppBar(), body: const Text('report-form')),
        ),
      ],
    );

    await _pumpRouter(tester, router);

    await tester.tap(find.text('Buat laporan'));
    await tester.pumpAndSettle();

    expect(find.text('report-form'), findsOneWidget);
  });

  testWidgets('returning from the report form uses the session store', (
    tester,
  ) async {
    await _signIn();
    final repository = _RevealAfterReturnRepository();
    final router = GoRouter(
      initialLocation: Routes.myReports,
      routes: [
        GoRoute(
          path: Routes.myReports,
          builder: (context, state) => MyReportsPage(repository: repository),
        ),
        GoRoute(
          path: Routes.report,
          builder: (context, state) =>
              Scaffold(appBar: AppBar(), body: const Text('report-form')),
        ),
      ],
    );

    await _pumpRouter(tester, router);
    expect(find.text('Buat laporan'), findsOneWidget);

    await tester.tap(find.text('Buat laporan'));
    await tester.pumpAndSettle();

    MyReportsStore.instance.add(_report('r006'));
    router.pop();
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(find.byKey(const ValueKey('my-report-r006')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-reports-skeleton')), findsNothing);
  });

  testWidgets('shows a skeleton while the reports load', (tester) async {
    await _signIn();
    final repository = _ControlledRepository();

    await _pumpPage(tester, repository: repository, settle: false);
    await tester.pump();

    expect(find.byKey(const ValueKey('my-reports-skeleton')), findsOneWidget);

    repository.completer.complete([_report('r006')]);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('my-reports-skeleton')), findsNothing);
    expect(find.byKey(const ValueKey('my-report-r006')), findsOneWidget);
  });

  testWidgets('shows an error and retries the load', (tester) async {
    await _signIn();
    final repository = _FlakyRepository();

    await _pumpPage(tester, repository: repository);

    expect(
      find.text('Gagal memuat laporan. Periksa koneksi lalu coba lagi.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(repository.failuresRemaining, 0);
    expect(find.byKey(const ValueKey('my-report-r006')), findsOneWidget);
  });

  testWidgets('opens the detail sheet with tracker, photo, map and note', (
    tester,
  ) async {
    await _signIn();
    await _pumpPage(
      tester,
      repository: InMemoryReportRepository(),
      size: const Size(390, 1600),
      tileProvider: _FakeTileProvider(),
    );

    await tester.tap(find.byKey(const ValueKey('my-report-r006')));
    await tester.pumpAndSettle();

    final report = _report('r006');
    final sheet = find.byKey(const ValueKey('my-report-sheet-scroll'));
    final tracker = find.byKey(const ValueKey('my-report-tracker'));

    expect(find.text('Detail laporan'), findsOneWidget);
    expect(sheet, findsOneWidget);
    expect(tracker, findsOneWidget);
    for (final label in const [
      'Terkirim',
      'Diverifikasi',
      'Ditindaklanjuti',
      'Selesai',
    ]) {
      expect(
        find.descendant(of: tracker, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: tracker, matching: find.byIcon(Icons.check)),
      findsNWidgets(2),
    );

    expect(find.byKey(const ValueKey('my-report-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-report-map')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-report-marker')), findsOneWidget);

    final note = find.byKey(const ValueKey('my-report-verifier-note'));
    expect(
      find.descendant(
        of: note,
        matching: find.text(
          'Lokasi sudah ditandai untuk aksi bersih komunitas pada 12 Oktober 2026.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text(report.description)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text(
          'Tanggal laporan: '
          '${P04Format.date(report.reportedAt.toLocal(), 'id')}',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('my-report-open-actions')), findsNothing);
  });

  testWidgets('a report without a verifier note says it is waiting', (
    tester,
  ) async {
    await _signIn();
    await _pumpPage(
      tester,
      repository: InMemoryReportRepository(),
      size: const Size(390, 1600),
      tileProvider: _FakeTileProvider(),
    );

    await tester.tap(find.byKey(const ValueKey('my-report-r019')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('my-report-waiting-verification')),
      findsOneWidget,
    );
    expect(find.text('Menunggu verifikasi'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('my-report-tracker')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('my-report-open-actions')), findsNothing);
  });

  testWidgets('the report photo opens the zoomable viewer', (tester) async {
    await _signIn();
    await _pumpPage(
      tester,
      repository: InMemoryReportRepository(),
      size: const Size(390, 1600),
      tileProvider: _FakeTileProvider(),
    );

    await tester.tap(find.byKey(const ValueKey('my-report-r006')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('my-report-photo')));
    await tester.pumpAndSettle();

    expect(find.byType(ZoomablePhotoViewer), findsOneWidget);
  });

  testWidgets('a followed-up report links to the Aksi tab', (tester) async {
    await _signIn();
    final router = GoRouter(
      initialLocation: Routes.myReports,
      routes: [
        GoRoute(
          path: Routes.myReports,
          builder: (context, state) => MyReportsPage(
            repository: InMemoryReportRepository(),
            mapTileProvider: _FakeTileProvider(),
          ),
        ),
        GoRoute(
          path: Routes.actionAgenda,
          builder: (context, state) =>
              const Scaffold(body: Text('actions-page')),
        ),
      ],
    );

    await _pumpRouter(tester, router);

    await tester.tap(find.byKey(const ValueKey('my-report-r013')));
    await tester.pumpAndSettle();
    await _scrollToActions(tester);

    expect(
      find.byKey(const ValueKey('my-report-open-actions')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('my-report-open-actions')));
    await tester.pumpAndSettle();

    expect(find.text('actions-page'), findsOneWidget);
    expect(find.text('Detail laporan'), findsNothing);
  });

  testWidgets('the proof marker opens the detail at its proof section', (
    tester,
  ) async {
    await _signIn();
    await _pumpPage(
      tester,
      repository: InMemoryReportRepository(),
      size: const Size(390, 1600),
      tileProvider: _FakeTileProvider(),
    );

    final marker = find.byKey(const ValueKey('my-report-proof-marker'));
    await tester.ensureVisible(marker);
    await tester.tap(marker);
    await tester.pumpAndSettle();

    final proof = find.byKey(
      const ValueKey('my-report-completion-proof-section'),
    );
    expect(proof, findsOneWidget);
    expect(
      find.text(
        'Dua tukik pulih setelah observasi dan dilepas kembali ke habitatnya.',
      ),
      findsOneWidget,
    );
    final proofRect = tester.getRect(proof);
    final sheetRect = tester.getRect(
      find.byKey(const ValueKey('my-report-sheet-scroll')),
    );
    expect(proofRect.top, greaterThanOrEqualTo(sheetRect.top));
    expect(proofRect.top, lessThan(sheetRect.bottom));
  });

  testWidgets('a completed report shows the same related-action row', (
    tester,
  ) async {
    await _signIn();
    await _pumpPage(
      tester,
      repository: InMemoryReportRepository(),
      size: const Size(390, 1600),
      tileProvider: _FakeTileProvider(),
    );

    await tester.tap(find.byKey(const ValueKey('my-report-r001')));
    await tester.pumpAndSettle();
    await _scrollToActions(tester);

    expect(
      find.byKey(const ValueKey('my-report-open-actions')),
      findsOneWidget,
    );
  });
}
