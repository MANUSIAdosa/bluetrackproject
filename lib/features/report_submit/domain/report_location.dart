/// Outcome of a one-shot location request for the "Lapor Temuan" wizard.
///
/// The wizard turns each failure into a message that keeps the manual map
/// usable, so a permission or GPS problem never blocks the report.
enum ReportLocationFailure {
  /// Permission was refused in this session; the OS will ask again next time.
  permissionDenied,

  /// Permission is blocked until the user changes it in the app settings.
  permissionDeniedForever,

  /// Location services (GPS) are turned off on the device.
  serviceDisabled,

  /// No fix arrived within the configured time limit.
  timeout,

  /// Any other platform error (no sensor, browser restriction, …).
  unavailable,
}

/// A location fix, or the reason none could be obtained.
class ReportLocationResult {
  const ReportLocationResult.success({
    required this.latitude,
    required this.longitude,
  }) : failure = null;

  const ReportLocationResult.failed(this.failure)
    : latitude = null,
      longitude = null;

  final double? latitude;
  final double? longitude;
  final ReportLocationFailure? failure;

  bool get hasLocation => latitude != null && longitude != null;
}
