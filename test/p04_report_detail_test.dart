import 'dart:async';

import 'package:blue_track/features/project/data/report_repository.dart';
import 'package:blue_track/features/project/domain/data_failure.dart';
import 'package:blue_track/features/project/domain/report.dart';
import 'package:blue_track/features/project/presentation/widgets/p04_report_detail_sheet.dart';
import 'package:blue_track/shared/widgets/error_state.dart';
import 'package:blue_track/shared/widgets/skeleton.dart';
import 'package:blue_track/shared/widgets/zoomable_photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/report_fixtures.dart';
import 'support/test_harness.dart';

/// Opens the report detail sheet through the same public entry point P04 uses.
class _SheetHost extends StatelessWidget {
  const _SheetHost({
    required this.repository,
    this.reportId = 'r004',
    this.locationName = 'Pantai Sukamade',
  });

  final ReportRepository repository;
  final String reportId;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          key: const ValueKey('open-detail'),
          onPressed: () => showP04ReportDetailSheet(
            context,
            reportId: reportId,
            locationName: locationName,
            repository: repository,
          ),
          child: const Text('Buka detail'),
        ),
      ),
    );
  }
}

/// Repository with exactly one report, an optional gate and an optional error.
///
/// Only [getReportById] is used by the detail sheet, so the other methods are
/// deliberately unimplemented.
class _DetailRepository implements ReportRepository {
  _DetailRepository({this.report, this.gate});

  final Report? report;
  final Future<void>? gate;

  @override
  Future<Report> getReportById(String id) async {
    final gate = this.gate;
    if (gate != null) await gate;
    final report = this.report;
    if (report == null || report.id != id) throw ReportNotFoundException(id);
    return report;
  }

  @override
  Future<List<Report>> getReportsByLocation(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    ReportStatus? status,
    bool verifiedOnly = false,
  }) => throw UnimplementedError('Not used by the detail sheet');

  @override
  Future<List<Report>> getReportsByUser(
    String userId, {
    ReportStatus? status,
  }) => throw UnimplementedError('Not used by the detail sheet');

  @override
  Future<Report> submitReport(ReportDraft draft) =>
      throw UnimplementedError('Not used by the detail sheet');

  @override
  Future<ReportSummary> getReportSummary(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    bool verifiedOnly = false,
  }) => throw UnimplementedError('Not used by the detail sheet');

  @override
  Future<List<MonthlyConditionPoint>> getMonthlyConditionTrend(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
  }) => throw UnimplementedError('Not used by the detail sheet');
}

Report _buildReport({
  String id = 'r-test',
  String title = 'Laporan uji',
  String description = 'Deskripsi laporan uji.',
  List<String> photoPaths = const [
    'assets/mock/report_photo_marine_debris.png',
  ],
  double? wasteKg = 12.5,
  double? areaM2,
  String? verifierNote = 'Sudah ditangani oleh tim lapangan.',
}) {
  return Report(
    id: id,
    locationId: 'p01',
    reporterId: 'u-test',
    reporterName: 'Pelapor Uji',
    category: ReportCategory.marineDebris,
    severity: ReportSeverity.medium,
    status: ReportStatus.verified,
    reportedAt: DateTime.utc(2026, 10, 20, 9),
    title: title,
    description: description,
    latitude: -8.52,
    longitude: 114.61,
    photoPaths: photoPaths,
    verifierNote: verifierNote,
    wasteKg: wasteKg,
    areaM2: areaM2,
  );
}

void _setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openSheet(
  WidgetTester tester, {
  required ReportRepository repository,
  String reportId = 'r004',
  String locationName = 'Pantai Sukamade',
  Locale locale = const Locale('id'),
  bool settle = true,
}) async {
  await tester.pumpWidget(
    wrapPage(
      _SheetHost(
        repository: repository,
        reportId: reportId,
        locationName: locationName,
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('open-detail')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Finish the modal entrance animation without settling: the skeleton
    // shimmer repeats forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Finder _detailScrollable() => find
    .descendant(
      of: find.byKey(const ValueKey('p04-detail-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

/// Simulates the Android system back button through the platform channel.
Future<void> _pressSystemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P04 report detail sheet', () {
    testWidgets('loads the report by id and shows every metadata field', (
      tester,
    ) async {
      _setScreen(tester, const Size(500, 1200));
      await _openSheet(tester, repository: InMemoryReportRepository());

      expect(find.text('Detail laporan'), findsOneWidget);
      expect(
        find.text('Sampah plastik menutup akses pendaratan tukik'),
        findsOneWidget,
      );
      expect(find.text('Sampah laut'), findsOneWidget);
      expect(find.text('Berat'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.textContaining('Dimas Pratama'), findsOneWidget);
      expect(find.textContaining('Pantai Sukamade'), findsOneWidget);
      expect(find.text('42 kg'), findsOneWidget);
      expect(
        find.textContaining('Pembersihan selesai 5 Agustus 2026'),
        findsOneWidget,
      );
      // Only the public display name is shown, never contact details.
      expect(find.textContaining('@'), findsNothing);

      final close = find.byKey(const ValueKey('p04-detail-close'));
      expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
    });

    testWidgets('shows a skeleton while the report is loading', (tester) async {
      _setScreen(tester, const Size(500, 1200));
      final gate = Completer<void>();
      final report = _buildReport();
      await _openSheet(
        tester,
        repository: _DetailRepository(report: report, gate: gate.future),
        reportId: report.id,
        settle: false,
      );

      expect(find.byKey(const ValueKey('p04-detail-skeleton')), findsOneWidget);
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.text('Laporan uji'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('p04-detail-skeleton')), findsNothing);
      expect(find.text('Laporan uji'), findsOneWidget);
    });

    testWidgets('shows ErrorState when the report id does not exist', (
      tester,
    ) async {
      _setScreen(tester, const Size(500, 1200));
      await _openSheet(
        tester,
        repository: _DetailRepository(report: _buildReport(id: 'r-known')),
        reportId: 'r-missing',
      );

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Laporan tidak ditemukan.'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses the English not-found copy', (tester) async {
      _setScreen(tester, const Size(500, 1200));
      await _openSheet(
        tester,
        repository: _DetailRepository(report: _buildReport(id: 'r-known')),
        reportId: 'r-missing',
        locale: const Locale('en'),
      );

      expect(find.text('Report not found.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows a placeholder when a report photo cannot be loaded', (
      tester,
    ) async {
      _setScreen(tester, const Size(500, 1200));
      final report = _buildReport(
        photoPaths: const ['assets/mock/does_not_exist.png'],
      );
      await _openSheet(
        tester,
        repository: _DetailRepository(report: report),
        reportId: report.id,
      );

      expect(find.text('Foto tidak dapat dimuat.'), findsOneWidget);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swipes photos and keeps the counter and dots in sync', (
      tester,
    ) async {
      _setScreen(tester, const Size(500, 1200));
      await _openSheet(tester, repository: InMemoryReportRepository());

      expect(find.text('1/2'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('p04-detail-dot-0'))).width,
        24,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('p04-detail-dot-1'))).width,
        13,
      );

      // A rightward photo swipe on the first page must not dismiss the sheet.
      await tester.drag(
        find.byKey(const ValueKey('p04-detail-gallery')),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Detail laporan'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('p04-detail-gallery')),
        const Offset(-450, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('p04-detail-dot-1'))).width,
        24,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('p04-detail-dot-0'))).width,
        13,
      );
    });

    testWidgets('opens the zoom viewer and double tap toggles 2x then 1x', (
      tester,
    ) async {
      _setScreen(tester, const Size(500, 1200));
      await _openSheet(tester, repository: InMemoryReportRepository());

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

      final viewer = find.byType(InteractiveViewer);
      final interactiveViewer = tester.widget<InteractiveViewer>(viewer);
      expect(interactiveViewer.minScale, 1);
      expect(interactiveViewer.maxScale, 4);
      final controller = interactiveViewer.transformationController!;
      expect(controller.value.getMaxScaleOnAxis(), closeTo(1, 0.001));

      await tester.tap(viewer);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(viewer);
      await tester.pumpAndSettle();
      expect(controller.value.getMaxScaleOnAxis(), closeTo(2, 0.001));

      await tester.tap(viewer);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(viewer);
      await tester.pumpAndSettle();
      expect(controller.value.getMaxScaleOnAxis(), closeTo(1, 0.001));

      final close = find.byTooltip('Tutup foto');
      expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(close).height, greaterThanOrEqualTo(48));

      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(ZoomablePhotoViewer), findsNothing);
      expect(find.text('Detail laporan'), findsOneWidget);
    });

    testWidgets('closes with the close button, system back and swipe down', (
      tester,
    ) async {
      _setScreen(tester, const Size(500, 1200));

      await _openSheet(tester, repository: InMemoryReportRepository());
      await tester.tap(find.byKey(const ValueKey('p04-detail-close')));
      await tester.pumpAndSettle();
      expect(find.text('Detail laporan'), findsNothing);

      await _openSheet(tester, repository: InMemoryReportRepository());
      await _pressSystemBack(tester);
      expect(find.text('Detail laporan'), findsNothing);

      await _openSheet(tester, repository: InMemoryReportRepository());
      await tester.drag(
        find.byKey(const ValueKey('p04-detail-scroll')),
        const Offset(0, 220),
      );
      await tester.pumpAndSettle();
      expect(find.text('Detail laporan'), findsNothing);
    });

    testWidgets('does not overflow with 600 characters at 320dp and 1.3x', (
      tester,
    ) async {
      _setScreen(tester, const Size(320, 800));
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      const sentence =
          'Kerusakan terumbu karang di lokasi ini perlu segera ditangani '
          'oleh tim lapangan. ';
      final description = (sentence * 8).substring(0, 600);
      final report = _buildReport(
        description: description,
        wasteKg: 3.5,
        areaM2: 120.5,
      );
      await _openSheet(
        tester,
        repository: _DetailRepository(report: report),
        reportId: report.id,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Detail laporan'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(description),
        200,
        scrollable: _detailScrollable(),
      );
      await tester.pumpAndSettle();

      expect(find.text(description), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
