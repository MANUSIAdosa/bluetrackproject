/// One P16 Learn article with its copy resolved for the active language.
///
/// The mock asset stores every text field twice (`titleId`/`titleEn`,
/// `summaryId`/`summaryEn`, `contentId`/`contentEn`), so switching language
/// only changes which pair [EducationArticle.fromJson] reads.
class EducationArticle {
  const EducationArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    required this.readingMinutes,
    required this.publishedAt,
    required this.imageAsset,
  });

  final String id;
  final String title;
  final String summary;
  final String content;

  /// Category id: polusi | ekosistem | perikanan_berkelanjutan |
  /// kawasan_konservasi.
  final String category;

  final int readingMinutes;
  final DateTime publishedAt;
  final String imageAsset;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'content': content,
    'category': category,
    'readingMinutes': readingMinutes,
    'publishedAt': publishedAt.toIso8601String(),
    'image': imageAsset,
  };

  factory EducationArticle.fromStoredJson(Map<String, dynamic> json) {
    return EducationArticle(
      id: json['id']! as String,
      title: json['title']! as String,
      summary: json['summary']! as String,
      content: json['content']! as String,
      category: json['category']! as String,
      readingMinutes: (json['readingMinutes']! as num).toInt(),
      publishedAt: DateTime.parse(json['publishedAt']! as String),
      imageAsset: json['image']! as String,
    );
  }

  /// Parses one article row. [languageCode] selects the Indonesian (`Id`) or
  /// English (`En`) pair, falling back to Indonesian for any other code.
  factory EducationArticle.fromJson(
    Map<String, dynamic> json, {
    String languageCode = 'id',
  }) {
    final suffix = languageCode == 'en' ? 'En' : 'Id';
    return EducationArticle(
      id: json['id']! as String,
      title: json['title$suffix']! as String,
      summary: json['summary$suffix']! as String,
      content: json['content$suffix']! as String,
      category: json['category']! as String,
      readingMinutes: (json['readingMinutes']! as num).toInt(),
      publishedAt: DateTime.parse(json['publishedAt']! as String),
      imageAsset: json['image']! as String,
    );
  }
}
