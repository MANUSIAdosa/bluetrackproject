import 'dart:async';

import 'package:blue_track/features/project/data/report_repository.dart';
import 'package:blue_track/features/project/domain/report.dart';
import 'package:blue_track/features/project/presentation/widgets/p04_reports_tab.dart';
import 'package:blue_track/shared/widgets/skeleton.dart';
import 'package:blue_track/shared/widgets/zoomable_photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/report_fixtures.dart';
import 'support/test_harness.dart';

/// Mirrors P04's parent page: the selected [ReportPeriod] lives above the tab,
/// so a period change survives the tab widget being reused or rebuilt.
class _ReportsHost extends StatefulWidget {
  const _ReportsHost({
    required this.repository,
    this.projectId = 'p01',
    this.locationName = 'Pantai Sukamade',
    this.initialPeriod = ReportPeriod.threeMonths,
  });

  final ReportRepository repository;
  final String projectId;
  final String locationName;
  final ReportPeriod initialPeriod;

  @override
  State<_ReportsHost> createState() => _ReportsHostState();
}

class _ReportsHostState extends State<_ReportsHost> {
  late ReportPeriod _period = widget.initialPeriod;

  @override
  Widget build(BuildContext context) {
    return P04ReportsTab(
      projectId: widget.projectId,
      locationName: widget.locationName,
      repository: widget.repository,
      period: _period,
      onPeriodChanged: (period) => setState(() => _period = period),
    );
  }
}

/// Delegating repository that can hold every call until [gate] completes,
/// so the loading state can be observed deterministically.
class _GatedReportRepository implements ReportRepository {
  _GatedReportRepository(this._delegate, this.gate);

  final ReportRepository _delegate;
  final Future<void> gate;

  Future<T> _wait<T>(Future<T> Function() call) async {
    await gate;
    return call();
  }

  @override
  Future<List<Report>> getReportsByLocation(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    ReportStatus? status,
    bool verifiedOnly = false,
  }) => _wait(
    () => _delegate.getReportsByLocation(
      locationId,
      period: period,
      status: status,
      verifiedOnly: verifiedOnly,
    ),
  );

  @override
  Future<Report> getReportById(String id) =>
      _wait(() => _delegate.getReportById(id));

  @override
  Future<List<Report>> getReportsByUser(
    String userId, {
    ReportStatus? status,
  }) => _wait(() => _delegate.getReportsByUser(userId, status: status));

  @override
  Future<Report> submitReport(ReportDraft draft) =>
      _wait(() => _delegate.submitReport(draft));

  @override
  Future<ReportSummary> getReportSummary(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    bool verifiedOnly = false,
  }) => _wait(
    () => _delegate.getReportSummary(
      locationId,
      period: period,
      verifiedOnly: verifiedOnly,
    ),
  );

  @override
  Future<List<MonthlyConditionPoint>> getMonthlyConditionTrend(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
  }) => _wait(
    () => _delegate.getMonthlyConditionTrend(locationId, period: period),
  );
}

/// Fails the first [failures] calls, then delegates to the real mock.
class _FlakyReportRepository implements ReportRepository {
  _FlakyReportRepository(this._delegate, {this.failures = 3});

  final ReportRepository _delegate;
  int failures;

  Future<T> _maybeFail<T>(Future<T> Function() call) async {
    if (failures > 0) {
      failures--;
      throw Exception('Simulated repository failure');
    }
    return call();
  }

  @override
  Future<List<Report>> getReportsByLocation(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    ReportStatus? status,
    bool verifiedOnly = false,
  }) => _maybeFail(
    () => _delegate.getReportsByLocation(
      locationId,
      period: period,
      status: status,
      verifiedOnly: verifiedOnly,
    ),
  );

  @override
  Future<Report> getReportById(String id) =>
      _maybeFail(() => _delegate.getReportById(id));

  @override
  Future<List<Report>> getReportsByUser(
    String userId, {
    ReportStatus? status,
  }) => _maybeFail(() => _delegate.getReportsByUser(userId, status: status));

  @override
  Future<Report> submitReport(ReportDraft draft) =>
      _maybeFail(() => _delegate.submitReport(draft));

  @override
  Future<ReportSummary> getReportSummary(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    bool verifiedOnly = false,
  }) => _maybeFail(
    () => _delegate.getReportSummary(
      locationId,
      period: period,
      verifiedOnly: verifiedOnly,
    ),
  );

  @override
  Future<List<MonthlyConditionPoint>> getMonthlyConditionTrend(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
  }) => _maybeFail(
    () => _delegate.getMonthlyConditionTrend(locationId, period: period),
  );
}

/// Returns a fixed set of already-aggregated data, used for the 12-report
/// pagination case that the bundled mock data cannot cover.
class _StaticReportRepository implements ReportRepository {
  _StaticReportRepository({required this.reports});

  final List<Report> reports;

  @override
  Future<List<Report>> getReportsByLocation(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    ReportStatus? status,
    bool verifiedOnly = false,
  }) async => List<Report>.of(reports);

  @override
  Future<Report> getReportById(String id) async =>
      reports.firstWhere((report) => report.id == id);

  @override
  Future<List<Report>> getReportsByUser(
    String userId, {
    ReportStatus? status,
  }) async => const [];

  @override
  Future<Report> submitReport(ReportDraft draft) =>
      throw UnimplementedError('Not needed by the P04 reports tab');

  @override
  Future<ReportSummary> getReportSummary(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    bool verifiedOnly = false,
  }) async => ReportSummary(
    totalWasteKg: 0,
    totalAreaM2: 0,
    verifiedReportCount: reports.length,
    totalReportCount: reports.length,
  );

  @override
  Future<List<MonthlyConditionPoint>> getMonthlyConditionTrend(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
  }) async => [
    MonthlyConditionPoint(
      month: DateTime.utc(2026, 9),
      averageScore: 2,
      reportCount: 6,
    ),
    MonthlyConditionPoint(
      month: DateTime.utc(2026, 10),
      averageScore: 2,
      reportCount: 6,
    ),
  ];
}

Report _pagedReport(int index) {
  return Report(
    id: 'f${index.toString().padLeft(2, '0')}',
    locationId: 'p01',
    reporterId: 'u-test',
    reporterName: 'Pelapor Uji',
    category: ReportCategory.marineDebris,
    severity: ReportSeverity.medium,
    status: ReportStatus.verified,
    reportedAt: DateTime.utc(2026, 10, 21 - index),
    title: 'Laporan uji $index',
    description: 'Deskripsi laporan uji $index.',
    latitude: -8.52,
    longitude: 114.61,
    photoPaths: const [],
    verifierNote: 'Catatan verifikator $index.',
    wasteKg: 1,
    areaM2: null,
  );
}

InMemoryReportRepository _repo() => InMemoryReportRepository();

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpReports(
  WidgetTester tester, {
  String projectId = 'p01',
  String locationName = 'Pantai Sukamade',
  ReportPeriod initialPeriod = ReportPeriod.threeMonths,
  ReportRepository? repository,
  Locale locale = const Locale('id'),
  bool settle = true,
}) async {
  _setScreen(tester, const Size(500, 1200));
  await tester.pumpWidget(
    wrapPage(
      _ReportsHost(
        repository: repository ?? _repo(),
        projectId: projectId,
        locationName: locationName,
        initialPeriod: initialPeriod,
      ),
      locale: locale,
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Finder _reportsScrollable() => find
    .descendant(
      of: find.byKey(const PageStorageKey('p04-reports-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

bool _isChipSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P04 reports tab', () {
    testWidgets('shows the loading skeleton before report data arrives', (
      tester,
    ) async {
      final gate = Completer<void>();
      await _pumpReports(
        tester,
        repository: _GatedReportRepository(_repo(), gate.future),
        settle: false,
      );
      await tester.pump();

      expect(find.byType(Skeleton), findsWidgets);
      expect(find.text('Ringkasan kondisi'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(Skeleton), findsNothing);
      expect(find.text('49,5 kg'), findsOneWidget);
    });

    testWidgets('renders metrics, trend and verified reports for 3 months', (
      tester,
    ) async {
      await _pumpReports(tester);

      expect(find.text('Ringkasan kondisi'), findsOneWidget);
      expect(find.text('Total estimasi sampah'), findsOneWidget);
      expect(find.text('49,5 kg'), findsOneWidget);
      expect(find.text('Laporan terverifikasi'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Tren kondisi lokasi'), findsOneWidget);
      expect(find.text('Makin rendah makin baik'), findsOneWidget);
      expect(find.byKey(const ValueKey('p04-condition-chart')), findsOneWidget);
      expect(find.text('Laporan warga'), findsOneWidget);
      expect(find.text('3 laporan'), findsOneWidget);
      expect(
        find.text('Perahu tanpa izin menangkap penyu di dekat pantai'),
        findsOneWidget,
      );
      // The submitted (Terkirim) report is filtered out of the public tab.
      expect(
        find.text('Penyu hijau terluka di bagian sirip depan'),
        findsNothing,
      );
      expect(find.text('Terkirim'), findsNothing);
    });

    testWidgets('period chips refilter the metrics, chart and list', (
      tester,
    ) async {
      await _pumpReports(tester);
      expect(_isChipSelected(tester, '3 bulan'), isTrue);
      expect(find.text('3 laporan'), findsOneWidget);

      await tester.tap(find.text('1 bulan'));
      await tester.pumpAndSettle();

      expect(_isChipSelected(tester, '1 bulan'), isTrue);
      expect(find.text('7,5 kg'), findsOneWidget);
      expect(find.text('2 laporan'), findsOneWidget);
      expect(find.byKey(const ValueKey('p04-chart-empty')), findsOneWidget);
      expect(
        find.text('Belum cukup data untuk menampilkan tren.'),
        findsOneWidget,
      );

      await tester.tap(find.text('6 bulan'));
      await tester.pumpAndSettle();

      expect(_isChipSelected(tester, '6 bulan'), isTrue);
      expect(find.text('68 kg'), findsOneWidget);
      expect(find.text('6 laporan'), findsOneWidget);
      expect(find.byKey(const ValueKey('p04-condition-chart')), findsOneWidget);

      await tester.tap(find.text('Semua'));
      await tester.pumpAndSettle();

      expect(_isChipSelected(tester, 'Semua'), isTrue);
      expect(find.text('68 kg'), findsOneWidget);
    });

    testWidgets('shows the affected-area metric when the summary has one', (
      tester,
    ) async {
      await _pumpReports(
        tester,
        projectId: 'p02',
        locationName: 'Pulau Pramuka',
        initialPeriod: ReportPeriod.all,
      );

      expect(find.text('5 kg'), findsOneWidget);
      expect(find.text('167,5 m²'), findsOneWidget);
      expect(find.byKey(const ValueKey('p04-metric-area')), findsOneWidget);
      expect(find.byKey(const ValueKey('p04-metric-waste')), findsOneWidget);
    });

    testWidgets('hides missing metrics instead of showing zero values', (
      tester,
    ) async {
      await _pumpReports(
        tester,
        projectId: 'p04',
        locationName: 'Teluk Weda',
        initialPeriod: ReportPeriod.all,
      );

      expect(find.byKey(const ValueKey('p04-metric-waste')), findsNothing);
      expect(find.byKey(const ValueKey('p04-metric-area')), findsNothing);
      expect(find.byKey(const ValueKey('p04-metric-verified')), findsOneWidget);
      expect(find.text('0 kg'), findsNothing);
      expect(find.text('0 m²'), findsNothing);
    });

    testWidgets('shows the empty chart and empty list for a location with no '
        'reports', (tester) async {
      await _pumpReports(
        tester,
        projectId: 'p06',
        locationName: 'Pesisir Makassar',
      );

      expect(find.byKey(const ValueKey('p04-chart-empty')), findsOneWidget);
      expect(
        find.text('Belum cukup data untuk menampilkan tren.'),
        findsOneWidget,
      );
      expect(
        find.text('Belum ada laporan terverifikasi pada periode ini.'),
        findsOneWidget,
      );
      expect(find.text('Ringkasan kondisi'), findsNothing);
      expect(find.text('Periode'), findsOneWidget);
      expect(find.text('3 bulan'), findsOneWidget);
    });

    testWidgets('shows an error state and retries successfully', (
      tester,
    ) async {
      await _pumpReports(
        tester,
        repository: _FlakyReportRepository(_repo(), failures: 3),
      );

      expect(find.text('Gagal memuat. Periksa koneksi Anda.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);

      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal memuat. Periksa koneksi Anda.'), findsNothing);
      expect(find.text('49,5 kg'), findsOneWidget);
      expect(find.text('3 laporan'), findsOneWidget);
    });

    testWidgets('caps the list at ten reports and loads more on demand', (
      tester,
    ) async {
      final reports = [for (var i = 1; i <= 12; i++) _pagedReport(i)];
      await _pumpReports(
        tester,
        repository: _StaticReportRepository(reports: reports),
        initialPeriod: ReportPeriod.all,
      );

      expect(find.text('12 laporan'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('p04-load-more')),
        300,
        scrollable: _reportsScrollable(),
      );
      // ensureVisible jumps the scroll position; a frame is needed before the
      // button's new on-screen offset is hit-testable.
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('p04-load-more')), findsOneWidget);
      expect(find.byKey(const ValueKey('p04-report-f11')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('p04-load-more')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('p04-load-more')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('p04-report-f11')),
        300,
        scrollable: _reportsScrollable(),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('p04-report-f11')), findsOneWidget);
    });

    testWidgets('uses English copy and locale-specific numbers', (
      tester,
    ) async {
      await _pumpReports(tester, locale: const Locale('en'));

      expect(find.text('3 months'), findsOneWidget);
      expect(find.text('Condition summary'), findsOneWidget);
      expect(find.text('Estimated waste total'), findsOneWidget);
      expect(find.text('49.5 kg'), findsOneWidget);
      expect(find.text('Citizen reports'), findsOneWidget);
      expect(find.text('3 reports'), findsOneWidget);
    });

    testWidgets('does not overflow at 320dp with 1.3x text scale', (
      tester,
    ) async {
      _setScreen(tester, const Size(320, 800));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(wrapPage(_ReportsHost(repository: _repo())));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Periode'), findsOneWidget);
      expect(find.text('3 bulan'), findsOneWidget);
    });
  });

  group('P04 report detail', () {
    testWidgets('opens a modal sheet with all report metadata', (tester) async {
      await _pumpReports(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('p04-report-r004')),
        300,
        scrollable: _reportsScrollable(),
      );

      await tester.tap(find.byKey(const ValueKey('p04-report-r004')));
      await tester.pumpAndSettle();

      expect(find.text('Detail laporan'), findsOneWidget);
      expect(
        find.text('Sampah plastik menutup akses pendaratan tukik'),
        findsWidgets,
      );
      expect(find.textContaining('Dimas Pratama'), findsOneWidget);
      expect(find.textContaining('Pantai Sukamade'), findsOneWidget);
      expect(find.text('Sampah laut'), findsOneWidget);
      expect(find.text('Berat'), findsWidgets);
      expect(find.text('Selesai'), findsWidgets);
      expect(find.text('42 kg'), findsOneWidget);
      expect(
        find.textContaining('Pembersihan selesai 5 Agustus 2026'),
        findsOneWidget,
      );

      final closeButton = find.byTooltip('Tutup');
      expect(tester.getSize(closeButton).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(closeButton).height, greaterThanOrEqualTo(48));

      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      expect(find.text('Detail laporan'), findsNothing);
    });

    testWidgets('opens the full-screen photo viewer from the detail sheet', (
      tester,
    ) async {
      await _pumpReports(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('p04-report-r004')),
        300,
        scrollable: _reportsScrollable(),
      );
      await tester.tap(find.byKey(const ValueKey('p04-report-r004')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('p04-detail-photo')).first);
      await tester.pumpAndSettle();

      expect(find.byType(ZoomablePhotoViewer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ZoomablePhotoViewer),
          matching: find.text('1/2'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Tutup foto'));
      await tester.pumpAndSettle();

      expect(find.byType(ZoomablePhotoViewer), findsNothing);
      expect(find.text('Detail laporan'), findsOneWidget);
    });
  });

  group('ZoomablePhotoViewer', () {
    testWidgets('swipes pages, toggles 2x zoom and closes', (tester) async {
      _setScreen(tester, const Size(500, 900));
      var closed = false;
      await tester.pumpWidget(
        wrapPage(
          ZoomablePhotoViewer(
            photoPaths: const [
              'assets/mock/report_photo_marine_debris.png',
              'assets/mock/report_photo_wildlife.png',
              'assets/mock/report_photo_coral_reef.png',
            ],
            closeLabel: 'Tutup foto',
            errorLabel: 'Foto tidak dapat dimuat.',
            counterLabel: (current, total) => '${current + 1}/$total',
            zoomHint: 'Cubit atau ketuk dua kali untuk memperbesar',
            onClose: () => closed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);
      expectedCloseSize(tester, 'Tutup foto');

      await tester.drag(find.byType(PageView), const Offset(-450, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);

      final interactiveViewer = find.byType(InteractiveViewer);
      final controller = tester
          .widget<InteractiveViewer>(interactiveViewer)
          .transformationController!;
      expect(controller.value.getMaxScaleOnAxis(), closeTo(1, 0.001));

      await tester.tap(interactiveViewer);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(interactiveViewer);
      await tester.pumpAndSettle();
      expect(controller.value.getMaxScaleOnAxis(), closeTo(2, 0.001));

      await tester.tap(interactiveViewer);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(interactiveViewer);
      await tester.pumpAndSettle();
      expect(controller.value.getMaxScaleOnAxis(), closeTo(1, 0.001));

      await tester.tap(find.byTooltip('Tutup foto'));
      expect(closed, isTrue);
    });

    testWidgets('shows an error placeholder for a missing image', (
      tester,
    ) async {
      _setScreen(tester, const Size(500, 900));
      await tester.pumpWidget(
        wrapPage(
          ZoomablePhotoViewer(
            photoPaths: const ['assets/mock/does_not_exist.png'],
            closeLabel: 'Tutup foto',
            errorLabel: 'Foto tidak dapat dimuat.',
            counterLabel: (current, total) => '${current + 1}/$total',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Foto tidak dapat dimuat.'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });
  });
}

void expectedCloseSize(WidgetTester tester, String tooltip) {
  final finder = find.byTooltip(tooltip);
  expect(tester.getSize(finder).width, greaterThanOrEqualTo(48));
  expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
}
