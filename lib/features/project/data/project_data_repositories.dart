import 'report_repository.dart';
import 'review_repository.dart';

/// Feature-local repository registry for the reporting data layer.
///
/// Pages should read [reports] and [reviews] instead of constructing the mock
/// classes directly, so replacing the mocks with an API client later only
/// changes this file.
///
/// The app-wide registry lives in `lib/features/repositories.dart`, which is
/// outside this iteration's write boundary. TODO(registry): move these two
/// entries there once its owner approves.
abstract final class ProjectDataRepositories {
  /// Citizen reports for P04, P07 and P10.
  static final ReportRepository reports = MockReportRepository();

  /// Location reviews for P04.
  static final ReviewRepository reviews = MockReviewRepository();
}
