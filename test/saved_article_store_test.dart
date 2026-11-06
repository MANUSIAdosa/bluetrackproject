import 'dart:io';

import 'package:blue_track/features/learn/data/saved_article_store.dart';
import 'package:blue_track/features/learn/domain/education_article.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

EducationArticle _article(String id, {String title = 'Artikel laut'}) =>
    EducationArticle(
      id: id,
      title: title,
      summary: 'Ringkasan lengkap',
      content: 'Isi artikel lengkap.',
      author: 'Penulis Uji',
      category: 'polusi',
      readingMinutes: 5,
      publishedAt: DateTime(2026, 10, 20),
      imageAsset: 'assets/images/interests/marine_waste.jpg',
    );

void main() {
  late Directory hiveDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('bluetrack_saved_articles');
    Hive.init(hiveDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  test('saved articles survive closing and reopening the Hive box', () async {
    final store = SavedArticleStore.instance;
    await store.save(_article('a01', title: 'Penyu Hijau'));
    await store.save(_article('a02', title: 'Karang Sehat'));

    await Hive.close();

    final loaded = await store.loadAll();

    expect(loaded.map((article) => article.id), ['a01', 'a02']);
    expect(loaded.first.title, 'Penyu Hijau');
    expect(loaded.first.content, 'Isi artikel lengkap.');
  });

  test('removing an article leaves other snapshots intact', () async {
    final store = SavedArticleStore.instance;
    await store.save(_article('a01'));
    await store.save(_article('a02'));

    await store.remove('a01');

    expect((await store.loadAll()).map((article) => article.id), ['a02']);
  });

  test('malformed snapshots are skipped', () async {
    final box = await Hive.openBox<dynamic>(SavedArticleStore.boxName);
    await box.put('broken', '{not-json');
    await SavedArticleStore.instance.save(_article('a01'));

    final loaded = await SavedArticleStore.instance.loadAll();

    expect(loaded.map((article) => article.id), ['a01']);
  });
}
