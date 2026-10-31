import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/project/domain/report.dart';
import 'package:blue_track/features/report_submit/data/my_reports_store.dart';
import 'package:blue_track/features/report_submit/data/report_draft_store.dart';
import 'package:blue_track/features/report_submit/data/report_submission_service.dart';
import 'package:blue_track/features/report_submit/domain/report_draft.dart';
import 'package:blue_track/features/report_submit/presentation/pages/my_reports_page.dart';
import 'package:blue_track/features/report_submit/presentation/pages/report_success_page.dart';
import 'package:blue_track/features/report_submit/presentation/pages/report_wizard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_tile_provider.dart';
import 'support/test_harness.dart';

/// 1x1 transparent PNG so `Image.file` has a real file to decode.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
  '/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
);

class _RecordingStore implements ReportDraftStore {
  _RecordingStore(this.draft);

  ReportWizardDraft? draft;
  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<ReportWizardDraft?> load() async => draft;

  @override
  Future<void> save(ReportWizardDraft draft) async {
    this.draft = draft;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    draft = null;
    clearCount++;
  }
}

class _ControllableService implements ReportSubmissionService {
  _ControllableService(this.reports);

  final MyReportsStore reports;
  final Completer<Report> _completer = Completer<Report>();
  int calls = 0;

  @override
  Future<Report> submit(ReportWizardDraft draft) {
    calls++;
    return _completer.future;
  }

  void completeWith(Report report) {
    reports.add(report);
    _completer.complete(report);
  }
}

class _FlakyService implements ReportSubmissionService {
  _FlakyService(this.reports);

  final MyReportsStore reports;
  int attempts = 0;

  @override
  Future<Report> submit(ReportWizardDraft draft) async {
    attempts++;
    await Future<void>.delayed(Duration.zero);
    if (attempts == 1) throw const ReportSubmissionException();
    final report = _buildReport(draft, id: 'RPT-RETRY');
    reports.add(report);
    return report;
  }
}

Report _buildReport(ReportWizardDraft draft, {String id = 'RPT-0001'}) {
  return Report(
    id: id,
    locationId: 'p01',
    reporterId: 'u-me',
    reporterName: 'Pengguna BlueTrack',
    category: draft.category ?? ReportCategory.damagedReef,
    severity: draft.severity ?? ReportSeverity.high,
    status: ReportStatus.submitted,
    reportedAt: DateTime.utc(2026, 10, 31, 10),
    title: 'Laporan temuan lapangan',
    description: 'Dikirim melalui Lapor Temuan BlueTrack.',
    latitude: draft.latitude ?? -8.52,
    longitude: draft.longitude ?? 114.61,
    photoPaths: draft.photoPaths,
    verifierNote: null,
    wasteKg: null,
    areaM2: null,
  );
}

void main() {
  late Directory tempDir;
  late String photoPath;
  late FakeTileProvider tileProvider;
  late MyReportsStore reports;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bluetrack_report_review_');
    final file = File('${tempDir.path}/proof.png');
    await file.writeAsBytes(_onePixelPng);
    photoPath = file.path;
    tileProvider = FakeTileProvider();
    reports = MyReportsStore();
    AuthController.instance.setSignedIn(false);
  });

  tearDown(() async {
    AuthController.instance.setSignedIn(false);
    OfflineController.instance.setOffline(false);
    await tempDir.delete(recursive: true);
  });

  ReportWizardDraft reviewDraft({
    ReportCategory? category = ReportCategory.damagedReef,
    ReportSeverity? severity = ReportSeverity.high,
    List<String>? photoPaths,
  }) {
    return ReportWizardDraft(
      photoPaths: photoPaths ?? [photoPath],
      latitude: -8.5236,
      longitude: 114.6131,
      category: category,
      severity: severity,
      currentStep: ReportWizardDraft.lastStep,
      updatedAt: DateTime.utc(2026, 10, 31, 9, 15),
    );
  }

  GoRouter buildRouter({
    required _RecordingStore store,
    required ReportSubmissionService service,
  }) {
    return GoRouter(
      initialLocation: '/report',
      routes: [
        GoRoute(
          path: '/report',
          builder: (context, state) => ReportWizardPage(
            store: store,
            submissionService: service,
            locationTileProvider: tileProvider,
            autoResume: state.uri.queryParameters['resume'] == '1',
          ),
        ),
        GoRoute(
          path: '/report/success/:id',
          builder: (context, state) => ReportSuccessPage(
            reportId: state.pathParameters['id'] ?? '',
            store: reports,
          ),
        ),
        GoRoute(
          path: '/my-reports',
          builder: (context, state) => MyReportsPage(store: reports),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text(
                'AUTH:${state.uri.queryParameters['redirect'] ?? ''}',
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const Scaffold(body: Text('PROFILE')),
        ),
      ],
    );
  }

  void phoneSurface(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
  }

  Future<void> openReview(
    WidgetTester tester, {
    required _RecordingStore store,
    required ReportSubmissionService service,
  }) async {
    phoneSurface(tester);
    final router = buildRouter(store: store, service: service);
    addTearDown(router.dispose);
    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjutkan draf'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('report_submit_button')));
  }

  testWidgets('review shows every section and keeps fields when editing', (
    tester,
  ) async {
    final store = _RecordingStore(reviewDraft());
    final service = _ControllableService(reports);
    await openReview(tester, store: store, service: service);

    expect(find.text('Tinjau laporan'), findsOneWidget);
    expect(find.text('Jenis temuan'), findsOneWidget);
    expect(find.text('Tingkat kerusakan'), findsOneWidget);
    expect(find.text('Terumbu rusak'), findsOneWidget);
    expect(find.text('Berat'), findsOneWidget);
    expect(find.text('Waktu'), findsOneWidget);
    expect(
      find.text('Laporan akan diverifikasi sebelum tayang ke publik.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Ubah'), findsNWidgets(4));

    // Photos open the full-screen viewer.
    await tester.tap(find.byKey(const ValueKey('report_review_photo_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report_photo_viewer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('report_photo_viewer_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report_photo_viewer')), findsNothing);

    // Editing the type goes back to step 3 without losing anything.
    final editType = find.byKey(const ValueKey('report_review_edit_type'));
    await tester.ensureVisible(editType);
    await tester.tap(editType);
    await tester.pumpAndSettle();
    expect(find.text('Jenis temuan'), findsOneWidget);
    // Autosave is debounced, so wait for it before asserting the stored draft.
    await tester.pump(const Duration(milliseconds: 600));
    expect(store.draft!.currentStep, ReportWizardDraft.typeStep);
    expect(store.draft!.category, ReportCategory.damagedReef);
    expect(store.draft!.severity, ReportSeverity.high);
    expect(store.draft!.photoCount, 1);

    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Tinjau laporan'), findsOneWidget);
  });

  testWidgets('sending shows a loading state, blocks a second tap and opens '
      'the success screen', (tester) async {
    AuthController.instance.setSignedIn(true);
    final store = _RecordingStore(reviewDraft());
    final service = _ControllableService(reports);
    await openReview(tester, store: store, service: service);

    await tapSubmit(tester);
    await tester.pump();

    expect(service.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // The primary button must ignore taps while the send is in flight.
    await tapSubmit(tester);
    await tester.pump();
    expect(service.calls, 1);

    service.completeWith(_buildReport(store.draft!));
    await tester.pumpAndSettle();

    expect(find.text('Laporan terkirim'), findsOneWidget);
    expect(find.text('RPT-0001'), findsOneWidget);
    expect(find.text('Terkirim'), findsOneWidget);
    expect(find.text('Terumbu rusak'), findsOneWidget);
    expect(find.text('Berat'), findsOneWidget);
    expect(store.draft, isNull);
    expect(reports.reports, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('report_success_view_reports')));
    await tester.pumpAndSettle();

    expect(find.text('Laporan Saya'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report_mine_item_RPT-0001')),
      findsOneWidget,
    );
  });

  testWidgets('a failed send keeps the draft and retry sends it', (
    tester,
  ) async {
    AuthController.instance.setSignedIn(true);
    final store = _RecordingStore(reviewDraft());
    final service = _FlakyService(reports);
    await openReview(tester, store: store, service: service);

    await tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Gagal mengirim laporan'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(store.draft, isNotNull);
    expect(store.draft!.category, ReportCategory.damagedReef);
    expect(find.text('Tinjau laporan'), findsOneWidget);

    final retry = find.byKey(const ValueKey('report_review_retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.text('Laporan terkirim'), findsOneWidget);
    expect(reports.reports.single.id, 'RPT-RETRY');
    expect(store.draft, isNull);
  });

  testWidgets('logged out review shows a prompt and sending opens login', (
    tester,
  ) async {
    final store = _RecordingStore(reviewDraft());
    final service = _ControllableService(reports);
    await openReview(tester, store: store, service: service);

    expect(find.text('Masuk untuk mengirim laporan'), findsOneWidget);
    expect(find.text('Laporan terkirim'), findsNothing);

    await tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('AUTH:/report?resume=1'), findsOneWidget);
    expect(store.draft, isNotNull);
    expect(store.draft!.category, ReportCategory.damagedReef);
    expect(service.calls, 0);
  });

  testWidgets('login redirect reopens the draft on step 4 without a dialog', (
    tester,
  ) async {
    phoneSurface(tester);
    final store = _RecordingStore(reviewDraft());
    final router = buildRouter(
      store: store,
      service: _ControllableService(reports),
    );
    addTearDown(router.dispose);
    router.go('/report?resume=1');

    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();

    expect(find.text('Lanjutkan draf?'), findsNothing);
    expect(find.text('Tinjau laporan'), findsOneWidget);
    expect(find.text('Terumbu rusak'), findsOneWidget);
  });

  testWidgets('offline blocks sending and explains why', (tester) async {
    AuthController.instance.setSignedIn(true);
    OfflineController.instance.setOffline(true);
    final store = _RecordingStore(reviewDraft());
    final service = _ControllableService(reports);
    await openReview(tester, store: store, service: service);

    expect(find.text('Butuh koneksi internet'), findsOneWidget);

    await tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(service.calls, 0);
    expect(find.text('Tinjau laporan'), findsOneWidget);
    expect(store.draft, isNotNull);
  });

  testWidgets('back from review returns to step 3 with the draft intact', (
    tester,
  ) async {
    final store = _RecordingStore(reviewDraft());
    final service = _ControllableService(reports);
    await openReview(tester, store: store, service: service);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Kembali'));
    await tester.pumpAndSettle();

    expect(find.text('Jenis temuan'), findsOneWidget);
    expect(store.draft!.currentStep, ReportWizardDraft.typeStep);
    expect(store.draft!.category, ReportCategory.damagedReef);
    expect(store.draft!.severity, ReportSeverity.high);
  });

  testWidgets('an incomplete draft is sent back to the missing step', (
    tester,
  ) async {
    AuthController.instance.setSignedIn(true);
    final store = _RecordingStore(reviewDraft(category: null, severity: null));
    final service = _ControllableService(reports);
    await openReview(tester, store: store, service: service);

    await tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(service.calls, 0);
    expect(find.text('Jenis temuan'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(store.draft!.currentStep, ReportWizardDraft.typeStep);
  });

  testWidgets('system back on success goes to My Reports, not the form', (
    tester,
  ) async {
    AuthController.instance.setSignedIn(true);
    final store = _RecordingStore(reviewDraft());
    final service = _FlakyService(reports);
    await openReview(tester, store: store, service: service);

    // The first attempt fails, the second succeeds.
    await tapSubmit(tester);
    await tester.pumpAndSettle();
    final retry = find.byKey(const ValueKey('report_review_retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('Laporan terkirim'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Laporan Saya'), findsOneWidget);
    expect(find.text('Tinjau laporan'), findsNothing);
  });

  testWidgets('a new report starts from an empty first step', (tester) async {
    AuthController.instance.setSignedIn(true);
    final store = _RecordingStore(reviewDraft());
    final service = _ControllableService(reports);
    await openReview(tester, store: store, service: service);

    await tapSubmit(tester);
    await tester.pump();
    service.completeWith(_buildReport(store.draft!));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('report_success_new_report')));
    await tester.pumpAndSettle();

    expect(find.text('Foto temuan'), findsOneWidget);
    expect(find.text('Laporan terkirim'), findsNothing);
    expect(store.draft, isNull);
  });

  testWidgets('My Reports starts empty and offers a new report', (
    tester,
  ) async {
    phoneSurface(tester);
    final router = buildRouter(
      store: _RecordingStore(null),
      service: _ControllableService(reports),
    );
    addTearDown(router.dispose);
    router.go('/my-reports');

    await tester.pumpWidget(wrapRouter(router));
    await tester.pumpAndSettle();

    expect(find.text('Laporan Saya'), findsOneWidget);
    expect(find.textContaining('Belum ada laporan'), findsOneWidget);
    expect(find.text('Buat Laporan'), findsOneWidget);
  });

  test('the in-memory draft store keeps the draft only in memory', () async {
    final store = InMemoryReportDraftStore();
    expect(await store.load(), isNull);

    const draft = ReportWizardDraft(
      photoPaths: ['/tmp/a.png'],
      category: ReportCategory.marineDebris,
      severity: ReportSeverity.low,
    );
    await store.save(draft);
    expect((await store.load())!.category, ReportCategory.marineDebris);

    await store.clear();
    expect(await store.load(), isNull);
  });
}
