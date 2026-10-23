import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/data_failure.dart';
import '../domain/location.dart';
import '../domain/report.dart';
import 'mock_repository_support.dart';

/// Data source contract for citizen reports (P04 Reports tab, P07, P10).
///
/// UI code depends on this interface only, so the mock implementation can be
/// replaced by an API client later without rewriting pages. All methods are
/// asynchronous and location ids match the P04 project ids.
abstract interface class ReportRepository {
  /// Reports for one location, newest first.
  ///
  /// [period] limits the results to a calendar-month window around the mock
  /// reference date. [status] further limits the results to one workflow
  /// status; omit it to get every status.
  ///
  /// Returns an empty list when the location exists but has no matching
  /// reports. Throws [LocationNotFoundException] when [locationId] is unknown.
  ///
  /// ```dart
  /// final reports = await repository.getReportsByLocation(
  ///   'p01',
  ///   period: ReportPeriod.threeMonths,
  ///   status: ReportStatus.verified,
  /// );
  /// ```
  Future<List<Report>> getReportsByLocation(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    ReportStatus? status,
  });

  /// One report by its unique [id].
  ///
  /// Throws [ReportNotFoundException] when no report has that id, including
  /// after reports submitted during the current session.
  ///
  /// ```dart
  /// final report = await repository.getReportById('r001');
  /// ```
  Future<Report> getReportById(String id);

  /// Reports submitted by one user, newest first.
  ///
  /// [status] optionally narrows the result to one workflow status. An unknown
  /// [userId] is not an error and returns an empty list.
  ///
  /// ```dart
  /// final mine = await repository.getReportsByUser(
  ///   'u01',
  ///   status: ReportStatus.submitted,
  /// );
  /// ```
  Future<List<Report>> getReportsByUser(String userId, {ReportStatus? status});

  /// Stores a new report and returns the stored version.
  ///
  /// The returned report always has [ReportStatus.submitted], a generated id
  /// and the repository's reference date as [Report.reportedAt]. It is visible
  /// to later reads immediately.
  ///
  /// Throws [LocationNotFoundException] when [ReportDraft.locationId] is
  /// unknown and [InvalidReportException] when required fields or
  /// category-specific metrics are missing.
  ///
  /// ```dart
  /// final report = await repository.submitReport(ReportDraft(...));
  /// ```
  Future<Report> submitReport(ReportDraft draft);

  /// Aggregate waste, area and verification metrics for one location.
  ///
  /// [period] applies the same calendar-month window as
  /// [getReportsByLocation]. Only reports with a non-null [Report.wasteKg] or
  /// [Report.areaM2] contribute to the totals. The verified count includes
  /// Diverifikasi, Ditindaklanjuti and Selesai, but not Terkirim.
  ///
  /// Returns zeroed metrics when the location has no reports in the window.
  /// Throws [LocationNotFoundException] when [locationId] is unknown.
  ///
  /// ```dart
  /// final summary = await repository.getReportSummary('p01');
  /// print(summary.totalWasteKg);
  /// ```
  Future<ReportSummary> getReportSummary(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
  });

  /// Monthly average severity for one location, oldest month first.
  ///
  /// Only reports with status Diverifikasi, Ditindaklanjuti or Selesai are
  /// included. A month without any such report has no point — it is omitted
  /// rather than reported as zero. [period] limits the months using the
  /// repository's injectable reference date.
  ///
  /// Returns an empty list when the location has no verified reports in the
  /// window. Throws [LocationNotFoundException] when [locationId] is unknown.
  ///
  /// ```dart
  /// final trend = await repository.getMonthlyConditionTrend(
  ///   'p01',
  ///   period: ReportPeriod.sixMonths,
  /// );
  /// ```
  Future<List<MonthlyConditionPoint>> getMonthlyConditionTrend(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
  });
}

/// Mock implementation reading `assets/mock/report.json` and
/// `assets/mock/locations.json`.
///
/// Reports submitted during the session are kept in memory. Creating a new
/// instance resets them to the asset contents.
class MockReportRepository implements ReportRepository {
  /// Creates a mock repository.
  ///
  /// [referenceDate] is the single mock "today" used by [ReportPeriod] and
  /// [getMonthlyConditionTrend]; it defaults to [kMockReferenceDate]. Inject it
  /// in tests or demos to move the six-month window.
  ///
  /// [latency] simulates a network call. Leave it null for a random 300–800 ms
  /// delay, or pass [Duration.zero] to disable it — required in tests.
  ///
  /// When [forceError] is true every method throws [MockRepositoryException]
  /// after the simulated delay, so Loading and Error states can be exercised.
  MockReportRepository({
    DateTime? referenceDate,
    this.latency,
    this.forceError = false,
  }) : referenceDate = (referenceDate ?? kMockReferenceDate).toUtc();

  static const _reportsAsset = 'assets/mock/report.json';
  static const _locationsAsset = 'assets/mock/locations.json';

  /// The mock "today" used by period filters and monthly trends.
  final DateTime referenceDate;

  /// Simulated call delay; null means a random 300–800 ms delay.
  final Duration? latency;

  /// When true, every method throws [MockRepositoryException].
  final bool forceError;

  List<Report>? _reports;
  Set<String>? _locationIds;

  Future<List<Report>> _loadReports() async {
    final cached = _reports;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_reportsAsset);
    final decoded = jsonDecode(raw) as List<dynamic>;
    final reports = decoded
        .map((item) => Report.fromJson(item as Map<String, dynamic>))
        .toList();
    return _reports = reports;
  }

  Future<Set<String>> _loadLocationIds() async {
    final cached = _locationIds;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_locationsAsset);
    final decoded = jsonDecode(raw) as List<dynamic>;
    final ids = decoded
        .map(
          (item) => ProjectLocation.fromJson(item as Map<String, dynamic>).id,
        )
        .toSet();
    return _locationIds = ids;
  }

  Future<void> _ensureLocation(String locationId) async {
    final ids = await _loadLocationIds();
    if (!ids.contains(locationId)) {
      throw LocationNotFoundException(locationId);
    }
  }

  List<Report> _inPeriod(List<Report> reports, ReportPeriod period) => reports
      .where((report) => period.contains(report.reportedAt, referenceDate))
      .toList();

  @override
  Future<List<Report>> getReportsByLocation(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
    ReportStatus? status,
  }) async {
    await simulateMockCall(latency: latency, forceError: forceError);
    await _ensureLocation(locationId);

    final reports =
        _inPeriod(await _loadReports(), period)
            .where((report) => report.locationId == locationId)
            .where((report) => status == null || report.status == status)
            .toList()
          ..sort(_newestFirst);
    return List<Report>.unmodifiable(reports);
  }

  @override
  Future<Report> getReportById(String id) async {
    await simulateMockCall(latency: latency, forceError: forceError);

    for (final report in await _loadReports()) {
      if (report.id == id) return report;
    }
    throw ReportNotFoundException(id);
  }

  @override
  Future<List<Report>> getReportsByUser(
    String userId, {
    ReportStatus? status,
  }) async {
    await simulateMockCall(latency: latency, forceError: forceError);

    final reports =
        (await _loadReports())
            .where((report) => report.reporterId == userId)
            .where((report) => status == null || report.status == status)
            .toList()
          ..sort(_newestFirst);
    return List<Report>.unmodifiable(reports);
  }

  @override
  Future<Report> submitReport(ReportDraft draft) async {
    await simulateMockCall(latency: latency, forceError: forceError);
    await _ensureLocation(draft.locationId);
    _validateDraft(draft);

    final reports = await _loadReports();
    final report = Report(
      id: _nextReportId(reports),
      locationId: draft.locationId,
      reporterId: draft.reporterId,
      reporterName: draft.reporterName,
      category: draft.category,
      severity: draft.severity,
      status: ReportStatus.submitted,
      reportedAt: referenceDate,
      title: draft.title,
      description: draft.description,
      latitude: draft.latitude,
      longitude: draft.longitude,
      photoPaths: List<String>.unmodifiable(draft.photoPaths),
      verifierNote: null,
      wasteKg: draft.wasteKg,
      areaM2: draft.areaM2,
    );
    reports.add(report);
    return report;
  }

  @override
  Future<ReportSummary> getReportSummary(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
  }) async {
    await simulateMockCall(latency: latency, forceError: forceError);
    await _ensureLocation(locationId);

    final reports = _inPeriod(
      await _loadReports(),
      period,
    ).where((report) => report.locationId == locationId);

    var wasteKg = 0.0;
    var areaM2 = 0.0;
    var verified = 0;
    var total = 0;
    for (final report in reports) {
      total++;
      wasteKg += report.wasteKg ?? 0;
      areaM2 += report.areaM2 ?? 0;
      if (report.hasPassedVerification) verified++;
    }

    return ReportSummary(
      totalWasteKg: wasteKg,
      totalAreaM2: areaM2,
      verifiedReportCount: verified,
      totalReportCount: total,
    );
  }

  @override
  Future<List<MonthlyConditionPoint>> getMonthlyConditionTrend(
    String locationId, {
    ReportPeriod period = ReportPeriod.all,
  }) async {
    await simulateMockCall(latency: latency, forceError: forceError);
    await _ensureLocation(locationId);

    final reports = _inPeriod(await _loadReports(), period)
        .where((report) => report.locationId == locationId)
        .where((report) => report.hasPassedVerification);

    final buckets = <DateTime, List<Report>>{};
    for (final report in reports) {
      final month = DateTime.utc(
        report.reportedAt.year,
        report.reportedAt.month,
      );
      (buckets[month] ??= <Report>[]).add(report);
    }

    final points = buckets.entries.map((entry) {
      final reportsInMonth = entry.value;
      final totalScore = reportsInMonth.fold<int>(
        0,
        (sum, report) => sum + report.severityScore,
      );
      return MonthlyConditionPoint(
        month: entry.key,
        averageScore: totalScore / reportsInMonth.length,
        reportCount: reportsInMonth.length,
      );
    }).toList()..sort((a, b) => a.month.compareTo(b.month));

    return List<MonthlyConditionPoint>.unmodifiable(points);
  }

  void _validateDraft(ReportDraft draft) {
    if (draft.reporterId.trim().isEmpty) {
      throw const InvalidReportException('reporterId must not be empty.');
    }
    if (draft.reporterName.trim().isEmpty) {
      throw const InvalidReportException('reporterName must not be empty.');
    }
    if (draft.title.trim().isEmpty) {
      throw const InvalidReportException('title must not be empty.');
    }
    if (draft.description.trim().isEmpty) {
      throw const InvalidReportException('description must not be empty.');
    }
    if (draft.photoPaths.isEmpty ||
        draft.photoPaths.any((path) => path.trim().isEmpty)) {
      throw const InvalidReportException(
        'At least one non-empty photo path is required.',
      );
    }
    if (draft.latitude < -90 || draft.latitude > 90) {
      throw const InvalidReportException(
        'latitude must be between -90 and 90.',
      );
    }
    if (draft.longitude < -180 || draft.longitude > 180) {
      throw const InvalidReportException(
        'longitude must be between -180 and 180.',
      );
    }
    if (draft.wasteKg != null && draft.wasteKg! <= 0) {
      throw const InvalidReportException('wasteKg must be greater than zero.');
    }
    if (draft.areaM2 != null && draft.areaM2! <= 0) {
      throw const InvalidReportException('areaM2 must be greater than zero.');
    }
    if (draft.category.requiresWasteKg && draft.wasteKg == null) {
      throw const InvalidReportException(
        'Marine debris reports require wasteKg.',
      );
    }
    if (draft.category.requiresAreaM2 && draft.areaM2 == null) {
      throw const InvalidReportException(
        'Reef and mangrove reports require areaM2.',
      );
    }
  }

  String _nextReportId(List<Report> reports) {
    var highest = 0;
    for (final report in reports) {
      if (!report.id.startsWith('r')) continue;
      final number = int.tryParse(report.id.substring(1));
      if (number != null && number > highest) highest = number;
    }
    return 'r${(highest + 1).toString().padLeft(3, '0')}';
  }

  int _newestFirst(Report a, Report b) {
    final byDate = b.reportedAt.compareTo(a.reportedAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }
}
