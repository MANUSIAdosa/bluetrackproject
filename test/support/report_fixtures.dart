import 'dart:convert';
import 'dart:io';

import 'package:blue_track/features/project/data/report_repository.dart';
import 'package:blue_track/features/project/domain/report.dart';

/// Parses the bundled report mock from disk once.
///
/// Widget tests cannot reliably await `rootBundle` after the first test in the
/// same file on Windows, so read the same JSON synchronously instead.
List<Report>? _reportsCache;

List<Report> mockReports() {
  final cached = _reportsCache;
  if (cached != null) return cached;

  final raw = File('assets/mock/report.json').readAsStringSync();
  final decoded = jsonDecode(raw) as List<dynamic>;
  return _reportsCache = decoded
      .map((item) => Report.fromJson(item as Map<String, dynamic>))
      .toList(growable: false);
}

/// In-memory [ReportRepository] with the same filtering rules as the mock,
/// backed by the real `assets/mock/report.json` fixtures.
class InMemoryReportRepository implements ReportRepository {
  InMemoryReportRepository({List<Report>? reports, DateTime? referenceDate})
    : _reports = List<Report>.of(reports ?? mockReports()),
      referenceDate = (referenceDate ?? DateTime.utc(2026, 10, 24)).toUtc();

  final List<Report> _reports;
  final DateTime referenceDate;

  List<Report> _matching(
    String locationId, {
    required ReportPeriod period,
    ReportStatus? status,
    bool verifiedOnly = false,
  }) {
    final reports =
        _reports
            .where((report) => report.locationId == locationId)
            .where(
              (report) => period.contains(report.reportedAt, referenceDate),
            )
            .where((report) => status == null || report.status == status)
            .where((report) => !verifiedOnly || report.hasPassedVerification)
            .toList()
          ..sort((a, b) {
            final byDate = b.reportedAt.compareTo(a.reportedAt);
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
    return reports;
  }

  @override
  Future<List<Report>> getReportsByLocation(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    ReportStatus? status,
    bool verifiedOnly = false,
  }) async => List<Report>.unmodifiable(
    _matching(
      locationId,
      period: period,
      status: status,
      verifiedOnly: verifiedOnly,
    ),
  );

  @override
  Future<Report> getReportById(String id) async =>
      _reports.firstWhere((report) => report.id == id);

  @override
  Future<List<Report>> getReportsByUser(
    String userId, {
    ReportStatus? status,
  }) async => List<Report>.unmodifiable(
    _reports
        .where((report) => report.reporterId == userId)
        .where((report) => status == null || report.status == status)
        .toList()
      ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt)),
  );

  @override
  Future<Report> submitReport(ReportDraft draft) =>
      throw UnimplementedError('Read-only test repository');

  @override
  Future<ReportSummary> getReportSummary(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    bool verifiedOnly = false,
  }) async {
    final reports = _matching(
      locationId,
      period: period,
      verifiedOnly: verifiedOnly,
    );
    var wasteKg = 0.0;
    var areaM2 = 0.0;
    var verified = 0;
    for (final report in reports) {
      wasteKg += report.wasteKg ?? 0;
      areaM2 += report.areaM2 ?? 0;
      if (report.hasPassedVerification) verified++;
    }
    return ReportSummary(
      totalWasteKg: wasteKg,
      totalAreaM2: areaM2,
      verifiedReportCount: verified,
      totalReportCount: reports.length,
    );
  }

  @override
  Future<List<MonthlyConditionPoint>> getMonthlyConditionTrend(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
  }) async {
    final reports = _matching(locationId, period: period, verifiedOnly: true);
    final buckets = <DateTime, List<Report>>{};
    for (final report in reports) {
      final month = DateTime.utc(
        report.reportedAt.year,
        report.reportedAt.month,
      );
      (buckets[month] ??= <Report>[]).add(report);
    }
    final points = buckets.entries.map((entry) {
      final monthReports = entry.value;
      final score = monthReports.fold<int>(
        0,
        (sum, report) => sum + report.severityScore,
      );
      return MonthlyConditionPoint(
        month: entry.key,
        averageScore: score / monthReports.length,
        reportCount: monthReports.length,
      );
    }).toList()..sort((a, b) => a.month.compareTo(b.month));
    return List<MonthlyConditionPoint>.unmodifiable(points);
  }
}
