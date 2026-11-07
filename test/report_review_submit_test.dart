import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blue_track/core/state/app_state.dart';
import 'package:blue_track/features/project/domain/report.dart';
import 'package:blue_track/features/my_reports/data/my_reports_store.dart';
import 'package:blue_track/features/report_submit/data/report_draft_store.dart';
import 'package:blue_track/features/report_submit/data/report_submission_service.dart';
import 'package:blue_track/features/report_submit/domain/report_draft.dart';
import 'package:blue_track/features/my_reports/presentation/my_reports_page.dart'
    as my_reports;
import 'package:blue_track/features/report_submit/presentation/pages/report_success_page.dart';
import 'package:blue_track/features/report_submit/presentation/pages/report_wizard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_tile_provider.dart';
import 'support/report_fixtures.dart';
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
  Future<Report> submit(ReportWizardDraft draft, {String languageCode = 'en'}) {
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
  Future<Report> submit(
    ReportWizardDraft draft, {
    String languageCode = 'en',
  }) async {
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
    reporterId: 'u01',
    reporterName: 'Pengguna BlueTrack',
    category: draft.category ?? ReportCategory.damagedReef,
    severity: draft.severity ?? ReportSeverity.high,
    status: ReportStatus.submitted,
    reportedAt: DateTime.utc(2026, 10, 31, 10),
    title: draft.title,
    description: draft.description,
    locationDetail: draft.locationDetail.trim().isEmpty
        ? null
        : draft.locationDetail.trim(),
    areaName: draft.areaName.trim().isEmpty ? null : draft.areaName.trim(),
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
    String? areaName = 'Pantai Sukamade, Banyuwangi',
    String? locationDetail = 'Sekitar 2 mil laut dari pulau.',
    String description = 'Penyu terlihat terjerat jaring plastik.',
  }) {
    return ReportWizardDraft(
      photoPaths: photoPaths ?? [photoPath],
      latitude: -8.5236,
      longitude: 114.6131,
      category: category,
      severity: severity,
      title: 'Penyu terjerat jaring',
      description: description,
      locationDetail: locationDetail ?? '',
      areaName: areaName ?? '',
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
          builder: (context, state) => my_reports.MyReportsPage(
            repository: InMemoryReportRepository(reports: const []),
            store: reports,
          ),
        ),
        GoRoute(
          path: '/explore',
          builder: (context, state) => const Scaffold(body: Text('EXPLORE')),
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
    expect(find.text('Terumbu rusak'), findsOneWidget);
    expect(find.text('Berat'), findsOneWidget);
    expect(
      find.text('Penyu terlihat terjerat jaring plastik.'),
      findsOneWidget,
    );
    expect(find.text('Penyu terjerat jaring'), findsOneWidget);
    expect(find.text('Pantai Sukamade, Banyuwangi'), findsOneWidget);
    expect(find.text('Sekitar 2 mil laut dari pulau.'), findsNothing);

    // Reading order: area name, then coordinates, then the folded detail.
    final areaY = tester
        .getTopLeft(find.byKey(const ValueKey('report_review_area_value')))
        .dy;
    final coordinatesY = tester
        .getTopLeft(find.byKey(const ValueKey('report_review_coordinates')))
        .dy;
    final detailsY = tester
        .getTopLeft(find.byKey(const ValueKey('report_review_details_toggle')))
        .dy;
    expect(areaY, lessThan(coordinatesY));
    expect(coordinatesY, lessThan(detailsY));

    // The landmark stays behind "Lihat rincian" so the summary stays clean.
    final details = find.byKey(const ValueKey('report_review_details_toggle'));
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('report_review_landmark_value')),
      findsOneWidget,
    );
    expect(find.text('Sekitar 2 mil laut dari pulau.'), findsOneWidget);

    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text('Sekitar 2 mil laut dari pulau.'), findsNothing);

    expect(find.text('Waktu'), findsOneWidget);
    expect(
      find.text('Laporan akan diverifikasi sebelum tayang ke publik.'),
      findsOneWidget,
    );
    // Photos, title and description share the step-1 group and one action.
    expect(find.widgetWithText(TextButton, 'Ubah'), findsNWidgets(3));

    // The reporter's title must outrank the group labels it sits under.
    final titleSize = tester
        .widget<Text>(find.byKey(const ValueKey('report_review_title_value')))
        .style!
        .fontSize!;
    final groupLabelSize = tester
        .widget<Text>(find.text('Foto dan keterangan'))
        .style!
        .fontSize!;
    expect(titleSize, greaterThan(groupLabelSize + 3));
    expect(find.text('Foto dan keterangan'), findsOneWidget);
    expect(find.text('Jenis dan tingkat'), findsOneWidget);

    // Photos open the full-screen viewer.
    final photo = find.byKey(const ValueKey('report_review_photo_0'));
    await tester.ensureVisible(photo);
    await tester.pumpAndSettle();
    await tester.tap(photo);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report_photo_viewer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('report_photo_viewer_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report_photo_viewer')), findsNothing);

    // One edit action returns to step 1 with both text fields intact.
    final editReport = find.byKey(const ValueKey('report_review_edit_report'));
    await tester.ensureVisible(editReport);
    await tester.tap(editReport);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report_title_field')), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('report_description_field')),
          )
          .initialValue,
      'Penyu terlihat terjerat jaring plastik.',
    );
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Lanjut'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Tinjau laporan'), findsOneWidget);

    // Editing the type goes back to step 3 without losing anything.
    final editType = find.byKey(
      const ValueKey('report_review_edit_classification'),
    );
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
    expect(find.text('Menunggu verifikasi'), findsOneWidget);
    expect(find.text('Pantai Sukamade, Banyuwangi'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report_success_coordinates')),
      findsOneWidget,
    );

    // The success screen closes the flow; the full report lives in the list.
    expect(find.text('Terumbu rusak'), findsNothing);
    expect(find.text('Berat'), findsNothing);
    expect(find.text('Penyu terlihat terjerat jaring plastik.'), findsNothing);
    expect(find.text('Sekitar 2 mil laut dari pulau.'), findsNothing);
    expect(store.draft, isNull);
    expect(reports.reports, hasLength(1));

    final viewReports = find.byKey(
      const ValueKey('report_success_view_reports'),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: viewReports,
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(viewReports);
    await tester.pumpAndSettle();
    expect(find.text('Laporan Saya'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-report-RPT-0001')), findsOneWidget);
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

  testWidgets('success block is centred and still scrolls on short screens', (
    tester,
  ) async {
    AuthController.instance.setSignedIn(true);
    final store = _RecordingStore(reviewDraft());
    final service = _ControllableService(reports);
    await openReview(tester, store: store, service: service);

    await tapSubmit(tester);
    await tester.pump();
    service.completeWith(_buildReport(store.draft!));
    await tester.pumpAndSettle();

    final screenHeight = tester.view.physicalSize.height;
    final top = tester.getRect(find.byIcon(Icons.check_circle_rounded)).top;
    final bottom = tester
        .getRect(find.byKey(const ValueKey('report_success_new_report')))
        .bottom;
    final gapAbove = top;
    final gapBelow = screenHeight - bottom;

    // Centred within the padding, so the two gaps are close to equal.
    expect((gapAbove - gapBelow).abs(), lessThan(24));
    expect(gapAbove, greaterThan(60));
  });

  testWidgets('long descriptions collapse to a preview that can expand', (
    tester,
  ) async {
    final longText = List.filled(
      6,
      'Seekor penyu ditemukan terlilit jaring plastik di perairan dekat '
      'dermaga dan masih dapat bergerak.',
    ).join(' ');
    final store = _RecordingStore(reviewDraft(description: longText));
    final service = _ControllableService(reports);
    await openReview(tester, store: store, service: service);

    final value = find.byKey(const ValueKey('report_review_description_value'));
    expect(tester.widget<Text>(value).maxLines, 3);

    final toggle = find.byKey(
      const ValueKey('report_review_description_toggle'),
    );
    expect(toggle, findsOneWidget);

    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(value).maxLines, isNull);
    expect(find.text('Sembunyikan'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(value).maxLines, 3);
  });

  testWidgets('short descriptions show no extra toggle', (tester) async {
    final store = _RecordingStore(reviewDraft());
    final service = _ControllableService(reports);
    await openReview(tester, store: store, service: service);

    expect(
      find.byKey(const ValueKey('report_review_description_toggle')),
      findsNothing,
    );
  });

  testWidgets('success keeps coordinates when no area name exists', (
    tester,
  ) async {
    AuthController.instance.setSignedIn(true);
    final store = _RecordingStore(
      reviewDraft(areaName: null, locationDetail: null),
    );
    final service = _ControllableService(reports);
    await openReview(tester, store: store, service: service);

    await tapSubmit(tester);
    await tester.pump();
    service.completeWith(_buildReport(store.draft!));
    await tester.pumpAndSettle();

    expect(find.text('Laporan terkirim'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('report_success_area_name')),
      findsNothing,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('report_success_coordinates')),
          )
          .data,
      '-8.523600, 114.613100',
    );
  });

  testWidgets('system back on success goes to Explore, not the form', (
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

    expect(find.text('EXPLORE'), findsOneWidget);
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

    final newReport = find.byKey(const ValueKey('report_success_new_report'));
    await tester.ensureVisible(newReport);
    await tester.tap(newReport);
    await tester.pumpAndSettle();

    expect(find.text('Foto temuan'), findsOneWidget);
    expect(find.text('Laporan terkirim'), findsNothing);
    expect(store.draft, isNull);
  });

  testWidgets('My Reports starts empty and offers a new report', (
    tester,
  ) async {
    AuthController.instance.setSignedIn(true);
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
    expect(find.text('Buat laporan'), findsOneWidget);
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
