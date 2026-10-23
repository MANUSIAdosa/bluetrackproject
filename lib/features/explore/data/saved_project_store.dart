import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../core/state/app_state.dart';
import '../domain/project.dart';

/// Flips the saved state of [project]: the id in the existing
/// `saved_projects` box (owned by `SavedProjectsController`) and the offline
/// snapshot in [SavedProjectStore].
///
/// Single entry point for every bookmark button — the list card, the map
/// sheet — so an id can never be saved without its offline copy.
Future<bool> toggleSavedProject(Project project) async {
  final controller = SavedProjectsController.instance;
  final wasSaved = controller.isSaved(project.id);
  await controller.toggle(project.id);
  if (wasSaved) {
    await SavedProjectStore.instance.remove(project.id);
  } else {
    await SavedProjectStore.instance.save(project);
  }
  return !wasSaved;
}

/// Offline copy of the bookmarked projects, so the saved collection still
/// opens without a connection (mock: without reading the repository/asset).
///
/// The saved *ids* stay in the existing `saved_projects` box owned by
/// [SavedProjectsController]; this store only adds the project payload under
/// the same id, in its own box, and is opened lazily so `main.dart` keeps
/// bootstrapping a single box.
class SavedProjectStore {
  SavedProjectStore._();

  static final SavedProjectStore instance = SavedProjectStore._();

  static const String boxName = 'saved_project_snapshots';

  Future<Box<dynamic>> _box() async => Hive.isBoxOpen(boxName)
      ? Hive.box<dynamic>(boxName)
      : Hive.openBox<dynamic>(boxName);

  /// Stores the full project under its id, replacing any earlier snapshot.
  Future<void> save(Project project) async {
    final box = await _box();
    await box.put(project.id, jsonEncode(project.toJson()));
  }

  Future<void> remove(String projectId) async {
    final box = await _box();
    await box.delete(projectId);
  }

  /// Every snapshot that can be decoded, oldest insertion first.
  ///
  /// A snapshot written by an older version of the model is skipped instead of
  /// breaking the whole offline list.
  Future<List<Project>> loadAll() async {
    final box = await _box();
    final projects = <Project>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! String) continue;
      try {
        projects.add(Project.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Ignore entries that no longer match the model.
      }
    }
    return projects;
  }
}
