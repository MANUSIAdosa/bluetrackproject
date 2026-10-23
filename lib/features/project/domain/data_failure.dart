/// Expected, typed failures thrown by the project data layer.
///
/// UI code can catch these instead of parsing generic exception messages.
sealed class RepositoryException implements Exception {
  const RepositoryException(this.message);

  /// Human-readable detail, intended for logs rather than direct UI copy.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a location id does not exist in `locations.json`.
class LocationNotFoundException extends RepositoryException {
  const LocationNotFoundException(this.locationId)
    : super('Location "$locationId" was not found.');

  /// The unknown location id that was requested.
  final String locationId;
}

/// Thrown when a report id does not exist in `report.json` or in reports
/// submitted during the current session.
class ReportNotFoundException extends RepositoryException {
  const ReportNotFoundException(this.reportId)
    : super('Report "$reportId" was not found.');

  /// The unknown report id that was requested.
  final String reportId;
}

/// Thrown by `submitReport` when a draft is incomplete or violates a category
/// rule.
class InvalidReportException extends RepositoryException {
  const InvalidReportException(super.message);
}

/// Thrown when a mock repository is constructed with `forceError: true`.
///
/// This exists so Loading and Error UI states can be exercised without a real
/// network failure.
class MockRepositoryException extends RepositoryException {
  const MockRepositoryException()
    : super('The mock repository is configured to fail.');
}
