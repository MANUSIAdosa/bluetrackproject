import 'package:blue_track/core/localization/app_localizations.dart';
import 'package:blue_track/core/theme/app_theme.dart';
import 'package:blue_track/features/learn/data/education_repository.dart';
import 'package:blue_track/features/learn/domain/education_article.dart';
import 'package:blue_track/features/learn/presentation/learn_article_detail_page.dart';
import 'package:blue_track/features/learn/presentation/learn_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class _FakeEducationRepository implements EducationRepository {
  _FakeEducationRepository(this.article);

  final EducationArticle article;
  int lookupCount = 0;

  @override
  Future<List<EducationArticle>> getArticles({String languageCode = 'id'}) =>
      Future.value([article]);

  @override
  List<EducationArticle> filterArticles(
    List<EducationArticle> articles, {
    String category = 'semua',
  }) => articles;

  @override
  Future<EducationArticle?> getArticleById(
    String id, {
    String languageCode = 'id',
  }) async {
    lookupCount++;
    return id == article.id ? article : null;
  }

  @override
  Future<void> saveArticle(EducationArticle article) async {}

  @override
  Future<void> removeArticle(String id) async {}

  @override
  Future<List<EducationArticle>> getSavedArticles({
    String languageCode = 'id',
  }) async => const [];
}

EducationArticle _article() => EducationArticle(
  id: 'a01',
  title: 'Dari Darat ke Laut',
  summary: 'Ringkasan artikel.',
  content: 'Paragraf pertama.\n\nParagraf kedua.',
  author: 'Penulis Uji',
  category: 'polusi',
  readingMinutes: 5,
  publishedAt: DateTime(2026, 10, 20),
  imageAsset: 'assets/images/interests/marine_waste.jpg',
);

Widget _app(Widget child) => MaterialApp(
  theme: buildAppTheme(),
  locale: const Locale('id'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repository gets an article by id', () async {
    final repository = MockEducationRepository();

    final article = await repository.getArticleById('a01');

    expect(article?.id, 'a01');
    expect(await repository.getArticleById('missing'), isNull);
  });

  testWidgets('article card opens detail page with complete article content', (
    tester,
  ) async {
    final article = _article();
    final repository = _FakeEducationRepository(article);
    await tester.pumpWidget(_app(LearnPage(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('learn-article-a01')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('learn-article-a01')));
    await tester.pumpAndSettle();
    expect(repository.lookupCount, 1);
    expect(find.byType(LearnArticleDetailPage), findsOneWidget);

    expect(find.text('Dari Darat ke Laut'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Paragraf pertama.'),
      300,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('p16-detail-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Paragraf pertama.'), findsOneWidget);
    expect(find.text('Paragraf kedua.'), findsOneWidget);
    expect(find.text('5 menit baca'), findsOneWidget);
    expect(find.text('Diterbitkan 20 Oktober 2026'), findsOneWidget);
    expect(find.text('Bagikan'), findsOneWidget);
  });

  testWidgets('missing article shows localized error state', (tester) async {
    await tester.pumpWidget(_app(const LearnArticleDetailPage.notFound()));
    await tester.pumpAndSettle();

    expect(find.text('Artikel tidak ditemukan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed image shows a placeholder without crashing', (
    tester,
  ) async {
    final article = EducationArticle(
      id: 'missing-image',
      title: 'Artikel gambar gagal',
      summary: 'Ringkasan',
      content: 'Konten',
      author: 'Penulis Uji',
      category: 'polusi',
      readingMinutes: 5,
      publishedAt: DateTime(2026, 10, 20),
      imageAsset: 'missing-image.png',
    );
    await tester.pumpWidget(_app(LearnArticleDetailPage(article: article)));
    await tester.pumpAndSettle();

    expect(find.text('Gambar tidak tersedia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long article fits on a narrow screen with larger text', (
    tester,
  ) async {
    final article = EducationArticle(
      id: 'long',
      title: 'A' * 100,
      summary: 'Ringkasan',
      content: 'B' * 1500,
      author: 'Penulis Uji',
      category: 'polusi',
      readingMinutes: 15,
      publishedAt: DateTime(2026, 10, 20),
      imageAsset: 'missing-image.png',
    );
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(320 * 3, 800 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _app(LearnArticleDetailPage(article: article)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A' * 100), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('share copies mock link and shows localized snackbar', (
    tester,
  ) async {
    final article = _article();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<dynamic, dynamic>)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(_app(LearnArticleDetailPage(article: article)));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('p16-detail-scroll')),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.tap(find.text('Bagikan'));
    await tester.pump();

    expect(copied, 'https://bluetrack.app/learn/a01');
    expect(find.text('Tautan disalin'), findsOneWidget);
  });
}
