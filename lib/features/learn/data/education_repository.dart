import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/education_article.dart';
import 'saved_article_store.dart';

/// Data source contract for P16 Learn articles.
///
/// The page only renders [EducationArticle] values; swapping this mock for an
/// API-backed implementation later must not change the card or page.
abstract interface class EducationRepository {
  /// Articles for [languageCode] (`'id'` or `'en'`).
  Future<List<EducationArticle>> getArticles({String languageCode = 'id'});

  /// Loads one article for its detail page.
  Future<EducationArticle?> getArticleById(
    String id, {
    String languageCode = 'id',
  });

  Future<void> saveArticle(EducationArticle article);

  Future<void> removeArticle(String id);

  Future<List<EducationArticle>> getSavedArticles({String languageCode = 'id'});

  /// Filters already-loaded articles without fetching them again.
  List<EducationArticle> filterArticles(
    List<EducationArticle> articles, {
    String category = 'semua',
  });
}

/// Mock implementation reading `assets/mock/education.json`.
///
/// The asset holds at least two articles for each of the four categories and
/// keeps every text field in both Indonesian and English. The returned order
/// is the asset order (newest article first).
class MockEducationRepository implements EducationRepository {
  MockEducationRepository({this.shouldFail = false});

  static const _asset = 'assets/mock/education.json';

  /// Test seam for simulating a failed article load.
  bool shouldFail;

  @override
  Future<List<EducationArticle>> getArticles({
    String languageCode = 'id',
  }) async {
    if (shouldFail) throw Exception('education repository failed');

    final raw = await rootBundle.loadString(_asset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rows = (decoded['articles']! as List<dynamic>)
        .cast<Map<String, dynamic>>();

    return [
      for (final row in rows)
        EducationArticle.fromJson(row, languageCode: languageCode),
    ];
  }

  @override
  Future<EducationArticle?> getArticleById(
    String id, {
    String languageCode = 'id',
  }) async {
    final articles = await getArticles(languageCode: languageCode);
    for (final article in articles) {
      if (article.id == id) return article;
    }
    return null;
  }

  @override
  Future<void> saveArticle(EducationArticle article) =>
      SavedArticleStore.instance.save(article);

  @override
  Future<void> removeArticle(String id) =>
      SavedArticleStore.instance.remove(id);

  @override
  Future<List<EducationArticle>> getSavedArticles({
    String languageCode = 'id',
  }) => SavedArticleStore.instance.loadAll(languageCode: languageCode);

  @override
  List<EducationArticle> filterArticles(
    List<EducationArticle> articles, {
    String category = 'semua',
  }) {
    if (category == 'semua') return List.of(articles);
    return articles.where((article) => article.category == category).toList();
  }
}
