import 'package:flutter/foundation.dart';

import '../../project/domain/report.dart';

/// Session-only store for reports submitted from "Lapor Temuan".
///
/// SIMULATION ONLY: the report is kept in memory until the save-report API
/// exists, so killing the app empties this list. Once the backend lands,
/// replace [add] with `ReportRepository.submitReport` and read "Laporan Saya"
/// from the repository instead.
///
/// TODO(lapor): remove this store and wire the wizard to ReportRepository
/// when the submit endpoint is available.
class MyReportsStore extends ChangeNotifier {
  MyReportsStore();

  static final MyReportsStore instance = MyReportsStore();

  final List<Report> _reports = [];

  /// Submitted reports, newest first.
  List<Report> get reports => List<Report>.unmodifiable(_reports);

  /// Report with [id], or null when the session no longer holds it.
  Report? byId(String id) {
    for (final report in _reports) {
      if (report.id == id) return report;
    }
    return null;
  }

  /// Number used for the next report id. Simulation stand-in for the id the
  /// server will issue.
  String nextReportNumber() {
    final sequence = (_reports.length + 1).toString().padLeft(4, '0');
    return 'RPT-$sequence';
  }

  void add(Report report) {
    _reports.insert(0, report);
    notifyListeners();
  }

  /// Clears the session list. Used by tests; production data disappears when
  /// the process ends.
  @visibleForTesting
  void reset() {
    _reports.clear();
    notifyListeners();
  }
}
