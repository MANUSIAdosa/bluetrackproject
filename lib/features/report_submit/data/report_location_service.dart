import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/report_location.dart';

/// One-shot location source used by Step 2 of the report wizard.
///
/// The wizard depends on this interface so widget tests can answer
/// deterministically and a future geocoding-backed implementation can replace
/// Geolocator without touching the page.
abstract interface class ReportLocationService {
  /// Asks for permission when needed and resolves a single fix.
  ///
  /// Never opens a position stream: the wizard only needs the point the user
  /// asked for, so there is nothing to cancel when the step is left.
  Future<ReportLocationResult> currentLocation();

  /// Opens the OS app settings (used after "denied forever").
  Future<bool> openAppSettings();

  /// Opens the OS location settings (used when GPS is disabled).
  Future<bool> openLocationSettings();
}

/// Geolocator-backed [ReportLocationService].
class GeolocatorReportLocationService implements ReportLocationService {
  const GeolocatorReportLocationService({
    this.timeLimit = const Duration(seconds: 12),
  });

  /// How long to wait for a fix. The platform reports `TimeoutException` when
  /// it elapses.
  final Duration timeLimit;

  /// A permission prompt is not covered by [LocationSettings.timeLimit] on
  /// every platform (notably the web `checkPermission` fallback), so the whole
  /// flow also gets this hard ceiling. Without it a dismissed browser prompt
  /// would leave the button spinning forever.
  Duration get _totalTimeLimit => timeLimit + const Duration(seconds: 18);

  @override
  Future<ReportLocationResult> currentLocation() async {
    try {
      return await _locate().timeout(_totalTimeLimit);
    } on TimeoutException {
      return const ReportLocationResult.failed(ReportLocationFailure.timeout);
    } catch (_) {
      return const ReportLocationResult.failed(
        ReportLocationFailure.unavailable,
      );
    }
  }

  Future<ReportLocationResult> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const ReportLocationResult.failed(
          ReportLocationFailure.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      // `unableToDetermine` is what the web returns when the Permission API is
      // unavailable; requesting is still worth a try there.
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return const ReportLocationResult.failed(
          ReportLocationFailure.permissionDeniedForever,
        );
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const ReportLocationResult.failed(
          ReportLocationFailure.permissionDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
      return ReportLocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      return const ReportLocationResult.failed(ReportLocationFailure.timeout);
    } on LocationServiceDisabledException {
      return const ReportLocationResult.failed(
        ReportLocationFailure.serviceDisabled,
      );
    } on PermissionDeniedException {
      return const ReportLocationResult.failed(
        ReportLocationFailure.permissionDenied,
      );
    } catch (_) {
      return const ReportLocationResult.failed(
        ReportLocationFailure.unavailable,
      );
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}
