import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/report_draft.dart';

/// Persistence contract for the single in-progress report draft.
///
/// The wizard depends on this interface so widget tests can use an in-memory
/// store and a future API-backed implementation can replace Hive without
/// touching the page.
abstract interface class ReportDraftStore {
  /// The stored draft, or null when none exists (or the stored value is
  /// unreadable).
  Future<ReportWizardDraft?> load();

  /// Replaces the stored draft.
  Future<void> save(ReportWizardDraft draft);

  /// Removes the stored draft, for example after a successful submission or
  /// when the user chooses "Mulai baru".
  Future<void> clear();
}

/// Hive-backed [ReportDraftStore].
///
/// The box is opened lazily so `main.dart` keeps bootstrapping only the
/// `saved_projects` box. The draft lives under one key because the wizard
/// only supports a single in-progress report.
class HiveReportDraftStore implements ReportDraftStore {
  HiveReportDraftStore();

  static final HiveReportDraftStore instance = HiveReportDraftStore();

  /// Box name for the wizard draft. Separate from the saved-project boxes.
  static const String boxName = 'report_drafts';

  /// Key holding the active draft.
  static const String activeKey = 'active';

  Future<Box<dynamic>> _box() async => Hive.isBoxOpen(boxName)
      ? Hive.box<dynamic>(boxName)
      : Hive.openBox<dynamic>(boxName);

  @override
  Future<ReportWizardDraft?> load() async {
    final box = await _box();
    final raw = box.get(activeKey);
    if (raw is! String || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final draft = ReportWizardDraft.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return draft.hasContent ? draft : null;
    } catch (_) {
      // A draft written by an older build must never block the wizard.
      return null;
    }
  }

  @override
  Future<void> save(ReportWizardDraft draft) async {
    final box = await _box();
    await box.put(activeKey, jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clear() async {
    final box = await _box();
    await box.delete(activeKey);
  }
}
