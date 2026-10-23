import 'package:blue_track/features/project/data/mock_repository_support.dart';
import 'package:blue_track/features/project/data/project_data_repositories.dart';
import 'package:blue_track/features/project/data/report_repository.dart';
import 'package:blue_track/features/project/domain/data_failure.dart';
import 'package:blue_track/features/project/domain/report.dart';
import 'package:flutter_test/flutter_test.dart';

MockReportRepository _repo({DateTime? referenceDate}) =>
    MockReportRepository(referenceDate: referenceDate, latency: Duration.zero);

ReportDraft _draft({
  String locationId = 'p01',
  ReportCategory category = ReportCategory.marineDebris,
  ReportSeverity severity = ReportSeverity.medium,
  String title = 'Laporan uji',
  String description = 'Deskripsi laporan uji.',
  List<String> photoPaths = const [
    'assets/mock/report_photo_marine_debris.png',
  ],
  double? wasteKg = 3.5,
  double? areaM2,
}) => ReportDraft(
  locationId: locationId,
  reporterId: 'u-test',
  reporterName: 'Penguji BlueTrack',
  category: category,
  severity: severity,
  title: title,
  description: description,
  latitude: -8.52,
  longitude: 114.61,
  photoPaths: photoPaths,
  wasteKg: wasteKg,
  areaM2: areaM2,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportPeriod', () {
    final reference = DateTime.utc(2026, 10, 24);

    test('windows start at the first day of the calculated month', () {
      expect(
        ReportPeriod.oneMonth.startFrom(reference),
        DateTime.utc(2026, 10),
      );
      expect(
        ReportPeriod.threeMonths.startFrom(reference),
        DateTime.utc(2026, 8),
      );
      expect(
        ReportPeriod.sixMonths.startFrom(reference),
        DateTime.utc(2026, 5),
      );
      expect(ReportPeriod.all.startFrom(reference), isNull);
    });

    test('the upper bound is exclusive and uses the reference month', () {
      expect(
        ReportPeriod.oneMonth.contains(DateTime.utc(2026, 10, 31), reference),
        isTrue,
      );
      expect(
        ReportPeriod.oneMonth.contains(DateTime.utc(2026, 11), reference),
        isFalse,
      );
      expect(
        ReportPeriod.threeMonths.contains(DateTime.utc(2026, 7, 31), reference),
        isFalse,
      );
      expect(
        ReportPeriod.threeMonths.contains(DateTime.utc(2026, 8), reference),
        isTrue,
      );
    });
  });

  group('ReportRepository reads', () {
    test('lists p01 reports newest first and applies period filters', () async {
      final repo = _repo();

      final all = await repo.getReportsByLocation('p01');
      expect(all.map((report) => report.id), [
        'r027',
        'r006',
        'r005',
        'r004',
        'r003',
        'r002',
        'r001',
      ]);

      final oneMonth = await repo.getReportsByLocation(
        'p01',
        period: ReportPeriod.oneMonth,
      );
      expect(oneMonth.map((report) => report.id), ['r027', 'r006']);

      final threeMonths = await repo.getReportsByLocation(
        'p01',
        period: ReportPeriod.threeMonths,
      );
      expect(threeMonths.map((report) => report.id), [
        'r027',
        'r006',
        'r005',
        'r004',
      ]);

      final sixMonths = await repo.getReportsByLocation(
        'p01',
        period: ReportPeriod.sixMonths,
      );
      expect(sixMonths, hasLength(7));
    });

    test('filters by status and combines it with the period', () async {
      final repo = _repo();

      final submitted = await repo.getReportsByLocation(
        'p01',
        status: ReportStatus.submitted,
      );
      expect(submitted.map((report) => report.id), ['r005']);

      final completed = await repo.getReportsByLocation(
        'p01',
        status: ReportStatus.completed,
      );
      expect(completed.map((report) => report.id), ['r004', 'r001']);

      final threeMonthsCompleted = await repo.getReportsByLocation(
        'p01',
        period: ReportPeriod.threeMonths,
        status: ReportStatus.completed,
      );
      expect(threeMonthsCompleted.map((report) => report.id), ['r004']);
    });

    test(
      'uses the injected reference date instead of the device clock',
      () async {
        final july = _repo(referenceDate: DateTime.utc(2026, 7, 15));

        final reports = await july.getReportsByLocation(
          'p01',
          period: ReportPeriod.oneMonth,
        );
        expect(reports.map((report) => report.id), ['r003']);

        final trend = await july.getMonthlyConditionTrend(
          'p01',
          period: ReportPeriod.oneMonth,
        );
        expect(trend.single.month, DateTime.utc(2026, 7));
        expect(trend.single.averageScore, 1.0);
      },
    );

    test(
      'a location without reports returns empty lists and zero metrics',
      () async {
        final repo = _repo();

        expect(await repo.getReportsByLocation('p06'), isEmpty);
        expect(await repo.getMonthlyConditionTrend('p06'), isEmpty);

        final summary = await repo.getReportSummary('p06');
        expect(summary.isEmpty, isTrue);
        expect(summary.totalWasteKg, 0);
        expect(summary.totalAreaM2, 0);
        expect(summary.verifiedReportCount, 0);
        expect(summary.totalReportCount, 0);
      },
    );

    test('unknown location throws a typed error', () async {
      final repo = _repo();

      await expectLater(
        repo.getReportsByLocation('p99'),
        throwsA(isA<LocationNotFoundException>()),
      );
      await expectLater(
        repo.getReportSummary('p99'),
        throwsA(isA<LocationNotFoundException>()),
      );
      await expectLater(
        repo.getMonthlyConditionTrend('p99'),
        throwsA(isA<LocationNotFoundException>()),
      );
    });

    test('report detail throws a typed error for an unknown id', () async {
      final repo = _repo();

      try {
        await repo.getReportById('r999');
        fail('expected ReportNotFoundException');
      } on ReportNotFoundException catch (error) {
        expect(error.reportId, 'r999');
      }
    });

    test('lists one user reports and filters them by status', () async {
      final repo = _repo();

      final mine = await repo.getReportsByUser('u01');
      expect(mine.map((report) => report.id), [
        'r006',
        'r019',
        'r023',
        'r013',
        'r001',
      ]);

      final completed = await repo.getReportsByUser(
        'u01',
        status: ReportStatus.completed,
      );
      expect(completed.map((report) => report.id), ['r023', 'r001']);

      final submitted = await repo.getReportsByUser(
        'u01',
        status: ReportStatus.submitted,
      );
      expect(submitted.map((report) => report.id), ['r019']);

      expect(await repo.getReportsByUser('u-unknown'), isEmpty);
    });

    test('summary totals waste, area and verified reports', () async {
      final repo = _repo();

      final p01 = await repo.getReportSummary('p01');
      expect(p01.totalWasteKg, closeTo(68.0, 0.001));
      expect(p01.totalAreaM2, 0);
      expect(p01.verifiedReportCount, 6);
      expect(p01.totalReportCount, 7);

      final p02 = await repo.getReportSummary('p02');
      expect(p02.totalWasteKg, closeTo(5.0, 0.001));
      expect(p02.totalAreaM2, closeTo(167.5, 0.001));
      expect(p02.verifiedReportCount, 4);
      expect(p02.totalReportCount, 5);

      final october = await repo.getReportSummary(
        'p01',
        period: ReportPeriod.oneMonth,
      );
      expect(october.totalWasteKg, closeTo(7.5, 0.001));
      expect(october.verifiedReportCount, 2);
      expect(october.totalReportCount, 2);
    });

    test(
      'monthly trend averages scores and omits months without data',
      () async {
        final repo = _repo();

        final trend = await repo.getMonthlyConditionTrend('p01');
        expect(trend.map((point) => point.month), [
          DateTime.utc(2026, 5),
          DateTime.utc(2026, 6),
          DateTime.utc(2026, 7),
          DateTime.utc(2026, 8),
          DateTime.utc(2026, 10),
        ]);
        expect(trend.map((point) => point.averageScore), [
          3.0,
          2.0,
          1.0,
          3.0,
          2.0,
        ]);
        expect(trend.map((point) => point.reportCount), [1, 1, 1, 1, 2]);

        final p02 = await repo.getMonthlyConditionTrend('p02');
        expect(p02.map((point) => point.month), [
          DateTime.utc(2026, 5),
          DateTime.utc(2026, 6),
          DateTime.utc(2026, 7),
          DateTime.utc(2026, 10),
        ], reason: 'months without verified reports must not appear as zero');
        expect(p02.map((point) => point.averageScore), [3.0, 1.0, 2.0, 1.0]);

        final threeMonths = await repo.getMonthlyConditionTrend(
          'p01',
          period: ReportPeriod.threeMonths,
        );
        expect(threeMonths.map((point) => point.month), [
          DateTime.utc(2026, 8),
          DateTime.utc(2026, 10),
        ]);
        expect(threeMonths.map((point) => point.averageScore), [3.0, 2.0]);
      },
    );
  });

  group('ReportRepository submit', () {
    test('new reports are Terkirim and visible to later reads', () async {
      final repo = _repo();
      final before = await repo.getReportsByLocation(
        'p01',
        period: ReportPeriod.oneMonth,
      );

      final report = await repo.submitReport(_draft());

      expect(report.id, 'r028');
      expect(report.status, ReportStatus.submitted);
      expect(report.hasPassedVerification, isFalse);
      expect(report.verifierNote, isNull);
      expect(report.reportedAt, repo.referenceDate);

      final fetched = await repo.getReportById(report.id);
      expect(fetched.id, report.id);
      expect(fetched.title, report.title);

      final after = await repo.getReportsByLocation(
        'p01',
        period: ReportPeriod.oneMonth,
      );
      expect(after, hasLength(before.length + 1));
      expect(after.map((item) => item.id), contains(report.id));

      final mine = await repo.getReportsByUser(
        'u-test',
        status: ReportStatus.submitted,
      );
      expect(mine.single.id, report.id);

      final summary = await repo.getReportSummary('p01');
      expect(summary.totalReportCount, 8);
      expect(summary.verifiedReportCount, 6);

      final trend = await repo.getMonthlyConditionTrend(
        'p01',
        period: ReportPeriod.oneMonth,
      );
      expect(trend.single.averageScore, 2.0);
      expect(trend.single.reportCount, 2);
    });

    test('rejects drafts that break category metric rules', () async {
      final repo = _repo();

      await expectLater(
        repo.submitReport(_draft(wasteKg: null)),
        throwsA(isA<InvalidReportException>()),
      );
      await expectLater(
        repo.submitReport(
          _draft(category: ReportCategory.damagedReef, wasteKg: null),
        ),
        throwsA(isA<InvalidReportException>()),
      );
      await expectLater(
        repo.submitReport(
          _draft(category: ReportCategory.deforestedMangrove, wasteKg: null),
        ),
        throwsA(isA<InvalidReportException>()),
      );
    });

    test('rejects drafts without a photo or a known location', () async {
      final repo = _repo();

      await expectLater(
        repo.submitReport(_draft(photoPaths: const [])),
        throwsA(isA<InvalidReportException>()),
      );
      await expectLater(
        repo.submitReport(_draft(locationId: 'p99')),
        throwsA(isA<LocationNotFoundException>()),
      );
    });

    test('accepts reef reports with the required area metric', () async {
      final repo = _repo();

      final report = await repo.submitReport(
        _draft(
          category: ReportCategory.damagedReef,
          wasteKg: null,
          areaM2: 4.5,
        ),
      );

      expect(report.category, ReportCategory.damagedReef);
      expect(report.areaM2, 4.5);
      expect(report.wasteKg, isNull);
    });
  });

  group('ReportRepository mock controls', () {
    test('forceError makes every call throw a typed mock error', () async {
      final repo = MockReportRepository(
        latency: Duration.zero,
        forceError: true,
      );

      await expectLater(
        repo.getReportsByLocation('p01'),
        throwsA(isA<MockRepositoryException>()),
      );
      await expectLater(
        repo.submitReport(_draft()),
        throwsA(isA<MockRepositoryException>()),
      );
    });

    test('the feature registry exposes the mock implementation', () {
      expect(ProjectDataRepositories.reports, isA<MockReportRepository>());
      expect(ProjectDataRepositories.reviews, isNotNull);
    });

    test('zero latency disables the simulated delay', () async {
      final stopwatch = Stopwatch()..start();
      await _repo().getReportsByLocation('p06');
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('declares the documented 300-800 ms simulated delay', () {
      expect(kMockLatencyMinMs, 300);
      expect(kMockLatencyMaxMs, 800);
    });
  });
}
