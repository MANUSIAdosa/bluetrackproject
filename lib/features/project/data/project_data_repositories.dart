import '../../explore/data/disbursement_repository.dart';
import 'report_repository.dart';
import 'review_repository.dart';

/// Feature-local repository registry for the reporting data layer.
///
/// Pages should read [reports], [reviews] and [disbursements] instead of
/// constructing the mock classes directly, so replacing the mocks with an API
/// client later only changes this file.
///
/// The app-wide registry lives in `lib/features/repositories.dart`, which is
/// outside this iteration's write boundary. TODO(registry): move these three
/// entries there once its owner approves.
abstract final class ProjectDataRepositories {
  /// Citizen reports for P04, P07 and P10.
  static final ReportRepository reports = MockReportRepository();

  /// Location reviews for P04.
  static final ReviewRepository reviews = MockReviewRepository();

  /// Fund disbursements for P04 (Penyaluran Dana).
  static final DisbursementRepository disbursements = MockDisbursementRepository();
}
