import 'dart:async';

import 'package:blue_track/features/report_submit/data/report_location_service.dart';
import 'package:blue_track/features/report_submit/domain/report_location.dart';

/// Deterministic [ReportLocationService] for widget tests.
class FakeReportLocationService implements ReportLocationService {
  FakeReportLocationService({
    this.result = const ReportLocationResult.failed(
      ReportLocationFailure.unavailable,
    ),
  });

  /// Answer for the next [currentLocation] call.
  ReportLocationResult result;

  /// When set, [currentLocation] waits for it so tests can inspect the loading
  /// state before completing.
  Completer<ReportLocationResult>? pending;

  bool appSettingsResult = true;
  bool locationSettingsResult = true;
  int appSettingsCalls = 0;
  int locationSettingsCalls = 0;

  @override
  Future<ReportLocationResult> currentLocation() {
    final completer = pending;
    if (completer != null) return completer.future;
    return Future.value(result);
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsCalls++;
    return appSettingsResult;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsCalls++;
    return locationSettingsResult;
  }
}
