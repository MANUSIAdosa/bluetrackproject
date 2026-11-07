import 'package:flutter/widgets.dart' show Locale;

import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/utils/formatters.dart';
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
  Future<Report> submit(
    ReportWizardDraft draft, {
    String languageCode = 'en',
  });
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
class MockReportSubmissionService implements ReportSubmissionService {
  static const _mockReportDescription =
      'Dikirim melalui Lapor Temuan BlueTrack.';

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
        draft.photoPaths.isEmpty) {
      throw const ReportSubmissionException('Draft is incomplete');
    }

    final reportedAt = DateTime.now().toUtc();
    final reportId = _store.nextReportNumber();
    final localizations = AppLocalizations(Locale(languageCode));
    final title = localizations.text('report_submit.generated_title', {
      'category': localizations.text(_categoryLabelKey(category)),
      'date': Formatters.dateTime(reportedAt, languageCode),
      'id': reportId,
    });

    final report = Report(
      id: reportId,
      locationId: AppConfig.reportSimulatedLocationId,
      reporterId: AppConfig.reportCurrentUserId,
      reporterName: AppConfig.reportCurrentUserName,
      category: category,
      severity: severity,
      status: ReportStatus.submitted,
      reportedAt: reportedAt,
      // The wizard collects no free-text description yet.
      title: title,
      description: _mockReportDescription,
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

  static String _categoryLabelKey(ReportCategory category) => switch (category) {
    ReportCategory.marineDebris => 'p04_category_marine_debris',
    ReportCategory.damagedReef => 'p04_category_damaged_reef',
    ReportCategory.deforestedMangrove => 'p04_category_deforested_mangrove',
    ReportCategory.destructiveFishing => 'p04_category_destructive_fishing',
    ReportCategory.affectedWildlife => 'p04_category_affected_wildlife',
  };
}
