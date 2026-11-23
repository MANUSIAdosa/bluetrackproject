import '../../../core/config/app_config.dart';
import '../../my_reports/data/my_reports_store.dart';
import '../../project/domain/report.dart';
import '../domain/report_draft.dart';

/// Sends a wizard draft to the (simulated) report store.
///
/// The wizard depends on this interface so tests can force success or failure
/// without waiting for the simulated delay.
abstract interface class ReportSubmissionService {
  /// Stores the draft and returns the created report.
  ///
  /// Throws when the simulated submission is configured to fail.
  Future<Report> submit(ReportWizardDraft draft, {String languageCode = 'en'});
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
/// [MyReportsStore], the same session collection read by My Reports.
///
/// The title is generated from the chosen category, date and report id, while
/// the description and the optional landmark come from the reporter.
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
  Future<Report> submit(
    ReportWizardDraft draft, {
    String languageCode = 'en',
  }) async {
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
        draft.photoPaths.isEmpty ||
        !draft.hasTitle ||
        !draft.hasDescription) {
      throw const ReportSubmissionException('Draft is incomplete');
    }

    final reportedAt = DateTime.now().toUtc();
    final reportId = _store.nextReportNumber();
    final title = draft.title.trim();

    final report = Report(
      id: reportId,
      locationId: AppConfig.reportSimulatedLocationId,
      reporterId: AppConfig.reportCurrentUserId,
      reporterName: AppConfig.reportCurrentUserName,
      category: category,
      severity: severity,
      status: ReportStatus.submitted,
      reportedAt: reportedAt,
      title: title,
      description: draft.description.trim(),
      locationDetail: draft.locationDetail.trim().isEmpty
          ? null
          : draft.locationDetail.trim(),
      areaName: draft.areaName.trim().isEmpty ? null : draft.areaName.trim(),
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
