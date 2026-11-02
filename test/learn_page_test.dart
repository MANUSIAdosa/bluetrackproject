import 'dart:async';

import 'package:blue_track/features/learn/data/education_repository.dart';
import 'package:blue_track/features/learn/domain/education_article.dart';
import 'package:blue_track/features/learn/presentation/learn_page.dart';
import 'package:blue_track/shared/widgets/empty_state.dart';
import 'package:blue_track/shared/widgets/error_state.dart';
import 'package:blue_track/shared/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

class _FakeEducationRepository implements EducationRepository {
  _FakeEducationRepository(
    this.articles, {
    List<EducationArticle> saved = const [],
  }) : savedArticles = List.of(saved);

  final List<EducationArticle> articles;
  final List<EducationArticle> savedArticles;
  bool shouldFail = false;
  bool shouldFailSavedLoad = false;
  bool shouldFailSave = false;
  int loadCount = 0;
  int filterCount = 0;
  Completer<List<EducationArticle>>? pendingLoad;

  @override
  Future<List<EducationArticle>> getArticles({String languageCode = 'id'}) {
    loadCount++;
    if (shouldFail) return Future.error(Exception('education failed'));
    final pending = pendingLoad;
    if (pending != null) return pending.future;
    return Future.value(articles);
  }

  @override
  Future<EducationArticle?> getArticleById(
    String id, {
    String languageCode = 'id',
  }) async => null;

  @override
  Future<void> saveArticle(EducationArticle article) async {
    if (shouldFailSave) throw Exception('save failed');
    savedArticles
      ..removeWhere((saved) => saved.id == article.id)
      ..add(article);
  }

  @override
  Future<void> removeArticle(String id) async {
    if (shouldFailSave) throw Exception('remove failed');
    savedArticles.removeWhere((saved) => saved.id == id);
  }

  @override
  Future<List<EducationArticle>> getSavedArticles({
    String languageCode = 'id',
  }) async {
    if (shouldFailSavedLoad) throw Exception('saved load failed');
    return List.of(savedArticles);
  }

  @override
  List<EducationArticle> filterArticles(
    List<EducationArticle> articles, {
    String category = 'semua',
  }) {
    filterCount++;
    if (category == 'semua') return List.of(articles);
    return articles.where((article) => article.category == category).toList();
  }
}

EducationArticle _article({
  required String id,
  required String category,
  String title = 'Artikel laut',
}) {
  return EducationArticle(
    id: id,
    title: title,
    summary: 'Ringkasan',
    content: 'Konten',
    category: category,
    readingMinutes: 5,
    publishedAt: DateTime(2026, 10, 20),
    imageAsset: 'assets/images/interests/coral_reef.jpg',
  );
}

Future<void> _pumpLearn(
  WidgetTester tester,
  _FakeEducationRepository repository, {
  double width = 360,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(width * 3, 800 * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    wrapPage(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: LearnPage(repository: repository),
      ),
    ),
  );
}

void main() {
  testWidgets('category chips filter loaded articles without reloading', (
    tester,
  ) async {
    final repository = _FakeEducationRepository([
      _article(id: 'a01', category: 'polusi', title: 'Artikel polusi'),
      _article(id: 'a02', category: 'ekosistem', title: 'Artikel ekosistem'),
    ]);
    await _pumpLearn(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.loadCount, 1);
    expect(find.text('Artikel polusi'), findsOneWidget);
    expect(find.text('Artikel ekosistem'), findsOneWidget);

    await tester.tap(find.byType(ChoiceChip).at(2));
    await tester.pump();

    expect(repository.loadCount, 1);
    expect(find.text('Artikel polusi'), findsNothing);
    expect(find.text('Artikel ekosistem'), findsOneWidget);
    expect(repository.filterCount, greaterThan(0));
  });

  testWidgets('saved chip shows saved articles and card toggles them', (
    tester,
  ) async {
    final article = _article(
      id: 'a01',
      category: 'polusi',
      title: 'Artikel tersimpan',
    );
    final repository = _FakeEducationRepository([article]);
    await _pumpLearn(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('learn-article-save-a01')));
    await tester.pumpAndSettle();
    expect(repository.savedArticles, hasLength(1));

    await tester.drag(find.byType(Scrollable).first, const Offset(-300, 0));
    await tester.pump();
    await tester.tap(find.text('Tersimpan'));
    await tester.pump();
    expect(find.text('Artikel tersimpan'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('learn-article-save-a01')));
    await tester.pumpAndSettle();
    expect(repository.savedArticles, isEmpty);
  });

  testWidgets('loading shows card-shaped skeletons', (tester) async {
    final repository = _FakeEducationRepository([])
      ..pendingLoad = Completer<List<EducationArticle>>();
    await _pumpLearn(tester, repository);
    await tester.pump();

    expect(find.byType(SkeletonCard), findsNWidgets(2));
  });

  testWidgets('an empty category shows EmptyState', (tester) async {
    final repository = _FakeEducationRepository([
      _article(id: 'a01', category: 'polusi'),
    ]);
    await _pumpLearn(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ChoiceChip).at(2));
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Belum ada artikel dalam kategori ini.'), findsOneWidget);
  });

  testWidgets('retry reloads after an education load failure', (tester) async {
    final repository = _FakeEducationRepository([
      _article(id: 'a01', category: 'polusi', title: 'Artikel pulih'),
    ])..shouldFail = true;
    await _pumpLearn(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    repository.shouldFail = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(repository.loadCount, 2);
    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Artikel pulih'), findsOneWidget);
  });

  testWidgets('a 100-character title fits at 320dp and text scale 1.3', (
    tester,
  ) async {
    final repository = _FakeEducationRepository([
      _article(id: 'a01', category: 'polusi', title: 'A' * 100),
    ]);
    await _pumpLearn(tester, repository, width: 320, textScale: 1.3);
    await tester.pumpAndSettle();

    expect(find.text('A' * 100), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
