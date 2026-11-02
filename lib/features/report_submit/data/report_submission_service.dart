import '../../../core/config/app_config.dart';
import '../../project/domain/report.dart';
import '../domain/report_draft.dart';
import 'my_reports_store.dart';

/// Sends a wizard draft to the (simulated) report store.
///
/// The wizard depends on this interface so tests can force success or failure
/// without waiting for the simulated delay.
abstract interface class ReportSubmissionService {
  /// Stores the draft and returns the created report.
  ///
  /// Throws when the simulated submission is configured to fail.
  Future<Report> submit(ReportWizardDraft draft);
}

/// Error thrown by [MockReportSubmissionService] when the simulated send
/// fails. The UI shows localized copy, so the message is only diagnostic.
class ReportSubmissionException implements Exception {
  const ReportSubmissionException([this.message = 'Simulated failure']);

  final String message;

  @override
  String toString() => 'ReportSubmissionException: $message';
}

/// Simulated submission: waits like a network call and saves the report to
/// [MyReportsStore] in memory.
///
/// The real API does not exist yet, and the wizard does not collect the fields
/// `ReportRepository.submitReport` requires (title, description, category
/// metrics), so this service builds a report directly.
///
/// TODO(lapor): replace with `ReportRepository.submitReport` plus the real
/// fields once the form and the backend are ready.
class MockReportSubmissionService implements ReportSubmissionService {
  MockReportSubmissionService({
    this.delay = AppConfig.reportSubmitDelay,
    this.simulateFailure = AppConfig.reportSubmitSimulateFailure,
    MyReportsStore? store,
  }) : _store = store ?? MyReportsStore.instance;

  /// Simulated network latency.
  final Duration delay;

  /// When true every submission throws [ReportSubmissionException], so the
  /// failure and retry states can be exercised.
  final bool simulateFailure;

  final MyReportsStore _store;

  @override
  Future<Report> submit(ReportWizardDraft draft) async {
    await Future<void>.delayed(delay);
    if (simulateFailure) throw const ReportSubmissionException();

    final category = draft.category;
    final severity = draft.severity;
    final latitude = draft.latitude;
    final longitude = draft.longitude;
    if (category == null ||
        severity == null ||
        latitude == null ||
        longitude == null ||
        draft.photoPaths.isEmpty) {
      throw const ReportSubmissionException('Draft is incomplete');
    }

    final report = Report(
      id: _store.nextReportNumber(),
      locationId: AppConfig.reportSimulatedLocationId,
      reporterId: AppConfig.reportCurrentUserId,
      reporterName: AppConfig.reportCurrentUserName,
      category: category,
      severity: severity,
      status: ReportStatus.submitted,
      reportedAt: DateTime.now().toUtc(),
      // The wizard collects no free-text fields; these placeholders keep the
      // domain model happy until a detail step exists.
      title: 'Laporan temuan lapangan',
      description: 'Dikirim melalui Lapor Temuan BlueTrack.',
      latitude: latitude,
      longitude: longitude,
      photoPaths: List<String>.unmodifiable(draft.photoPaths),
      verifierNote: null,
      wasteKg: null,
      areaM2: null,
    );

    _store.add(report);
    return report;
  }
}
