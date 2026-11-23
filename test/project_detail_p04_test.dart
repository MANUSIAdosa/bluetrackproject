import 'package:blue_track/features/project/data/report_repository.dart';
import 'package:blue_track/features/project/presentation/project_detail_page.dart';
import 'package:blue_track/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/report_fixtures.dart';
import 'support/test_harness.dart';

Future<void> _pumpDetail(
  WidgetTester tester, {
  String projectId = 'p01',
  ReportRepository? repository,
  Locale locale = const Locale('id'),
  String initialReportSection = 'kondisi',
  Size size = const Size(420, 950),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    wrapPage(
      ProjectDetailPage(
        projectId: projectId,
        projectRepository: FakeProjectRepository([
          buildProject(location: 'Pantai Sukamade, Jawa Timur'),
        ]),
        reportRepository: repository ?? InMemoryReportRepository(),
        initialReportSection: initialReportSection,
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

bool _chipSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

/// The reports list is the last section of the tab, so its header only enters
/// the lazy viewport after scrolling on a phone-sized screen. `.first` picks the
/// ListView's own scrollable, not scrollables inside the chart's EmptyState.
Finder _reportsScrollable() => find
    .descendant(
      of: find.byKey(const PageStorageKey('p04-reports-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

/// The report list header is the last section of the tab, so on a phone-sized
/// screen it only enters the lazy viewport after scrolling.
Future<void> _scrollToReportCount(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('2 laporan'),
    300,
    scrollable: _reportsScrollable(),
  );
  await tester.pumpAndSettle();
}

/// The tab body only fills the viewport once the header slivers above it have
/// scrolled away, so collapse them before asserting on the reports content.
Future<void> _collapseHeader(WidgetTester tester) async {
  await tester.drag(find.text('Target'), const Offset(0, -700));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows four tabs in order with Pendanaan instead of Anggaran', (
    tester,
  ) async {
    await _pumpDetail(tester);

    const labels = ['Tentang', 'Pendanaan', 'Laporan', 'Ulasan'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Anggaran'), findsNothing);

    final positions = [
      for (final label in labels) tester.getCenter(find.text(label)).dx,
    ];
    for (var i = 1; i < positions.length; i++) {
      expect(positions[i], greaterThan(positions[i - 1]));
    }

    await tester.tap(find.text('Pendanaan'));
    await tester.pumpAndSettle();

    expect(find.text('Pos pendanaan'), findsOneWidget);
    expect(find.text('Jumlah'), findsOneWidget);
    expect(find.text('Porsi'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Anggaran'), findsNothing);
  });

  testWidgets('English tabs use Funding and never Budget or Anggaran', (
    tester,
  ) async {
    await _pumpDetail(tester, locale: const Locale('en'));

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Funding'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('Budget'), findsNothing);
    expect(find.text('Anggaran'), findsNothing);

    await tester.tap(find.text('Funding'));
    await tester.pumpAndSettle();

    expect(find.text('Funding item'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('reports tab owns the space above the donate bar', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpDetail(tester, initialReportSection: 'penyaluran');
    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();

    // Collapse the header slivers so the whole tab body is on screen.
    await _collapseHeader(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(Skeleton), findsNothing);

    // The tab body must fill everything above the donate bar. A half-height
    // body clipped the last disbursement card and left dead space below it.
    final listHeight = tester
        .getSize(find.byKey(const PageStorageKey('p04-reports-scroll')))
        .height;
    final donateTop = tester.getRect(find.text('Donasi')).top;
    expect(listHeight, greaterThan(donateTop * 0.7));
  });

  testWidgets('keeps the selected report period after switching tabs', (
    tester,
  ) async {
    // Tall viewport: the period chips sit directly below the pinned tab bar, so
    // they are reachable without the fragile header-collapse dance.
    await _pumpDetail(tester, size: const Size(420, 1600));

    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();

    expect(_chipSelected(tester, '3 bulan'), isTrue);
    expect(find.text('49,5 kg'), findsOneWidget);

    await tester.tap(find.text('1 bulan'));
    await tester.pumpAndSettle();

    expect(_chipSelected(tester, '1 bulan'), isTrue);
    expect(find.text('7,5 kg'), findsOneWidget);
    await _scrollToReportCount(tester);
    expect(find.text('2 laporan'), findsOneWidget);

    await tester.tap(find.text('Tentang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();

    expect(_chipSelected(tester, '1 bulan'), isTrue);
    await _scrollToReportCount(tester);
    expect(find.text('2 laporan'), findsOneWidget);
  });
}
