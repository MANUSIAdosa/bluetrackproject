import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/education_article.dart';

class SavedArticleStore {
  SavedArticleStore._();

  static final SavedArticleStore instance = SavedArticleStore._();

  static const String boxName = 'saved_articles';

  Future<Box<dynamic>> _box() async => Hive.isBoxOpen(boxName)
      ? Hive.box<dynamic>(boxName)
      : Hive.openBox<dynamic>(boxName);

  Future<void> save(EducationArticle article) async {
    final box = await _box();
    await box.put(article.id, jsonEncode(article.toJson()));
  }

  Future<void> remove(String articleId) async {
    final box = await _box();
    await box.delete(articleId);
  }

  Future<List<EducationArticle>> loadAll({String languageCode = 'id'}) async {
    final box = await _box();
    final articles = <EducationArticle>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! String || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        articles.add(
          EducationArticle.fromStoredJson(Map<String, dynamic>.from(decoded)),
        );
      } catch (_) {
        // Ignore snapshots that no longer match the article model.
      }
    }
    return articles;
  }
}
