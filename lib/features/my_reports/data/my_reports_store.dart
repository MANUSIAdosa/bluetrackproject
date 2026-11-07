import 'package:flutter/foundation.dart';

import '../../project/domain/report.dart';

/// Session-level source for the personal report list and wizard submissions.
///
/// The mock report repository supplies bundled examples on first load; those
/// reports and new wizard submissions are then kept together here for the
/// current session. A process restart clears this simulation store.
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
    _reports.removeWhere((existing) => existing.id == report.id);
    _reports.insert(0, report);
    notifyListeners();
  }

  /// Adds repository seed reports without duplicating submissions already in
  /// the session store.
  void addAllIfMissing(Iterable<Report> reports) {
    final knownIds = _reports.map((report) => report.id).toSet();
    var changed = false;
    for (final report in reports) {
      if (knownIds.add(report.id)) {
        _reports.add(report);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Clears the session list. Used by tests; production data disappears when
  /// the process ends.
  @visibleForTesting
  void reset() {
    _reports.clear();
    notifyListeners();
  }
}
