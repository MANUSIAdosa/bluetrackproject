/// One section of an article body: a subheading plus one body paragraph.
class ArticleSection {
  const ArticleSection({required this.heading, required this.body});

  final String heading;
  final String body;

  Map<String, dynamic> toJson() => {'heading': heading, 'body': body};

  factory ArticleSection.fromJson(Map<String, dynamic> json) => ArticleSection(
    heading: json['heading'] as String? ?? '',
    body: json['body'] as String? ?? '',
  );
}

/// One P16 Learn article with its copy resolved for the active language.
///
/// The mock asset stores every text field twice (`titleId`/`titleEn`,
/// `summaryId`/`summaryEn`, …), so switching language only changes which pair
/// [EducationArticle.fromJson] reads. Articles saved before the structured
/// fields existed decode with empty lists, and the detail page hides those
/// sections instead of crashing.
class EducationArticle {
  const EducationArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.author,
    required this.category,
    required this.readingMinutes,
    required this.publishedAt,
    required this.imageAsset,
    this.keyPoints = const [],
    this.sections = const [],
    this.funFact = '',
    this.sources = const [],
    this.relatedIds = const [],
  });

  final String id;
  final String title;
  final String summary;
  final String content;

  /// Author name or publishing institution, resolved for the active language.
  final String author;

  /// Category id: polusi | ekosistem | perikanan_berkelanjutan |
  /// kawasan_konservasi.
  final String category;

  final int readingMinutes;
  final DateTime publishedAt;
  final String imageAsset;

  /// Exactly three short takeaways shown above the body.
  final List<String> keyPoints;

  /// Structured body: at least three heading + paragraph parts.
  final List<ArticleSection> sections;

  /// One "Did you know?" fact or figure.
  final String funFact;

  /// One to three reference lines.
  final List<String> sources;

  /// Three related article ids, ideally from the same category.
  final List<String> relatedIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'content': content,
    'author': author,
    'category': category,
    'readingMinutes': readingMinutes,
    'publishedAt': publishedAt.toIso8601String(),
    'image': imageAsset,
    'keyPoints': keyPoints,
    'sections': [for (final section in sections) section.toJson()],
    'funFact': funFact,
    'sources': sources,
    'relatedIds': relatedIds,
  };

  factory EducationArticle.fromStoredJson(Map<String, dynamic> json) {
    return EducationArticle(
      id: json['id']! as String,
      title: json['title']! as String,
      summary: json['summary']! as String,
      content: json['content']! as String,
      author: json['author'] as String? ?? '',
      category: json['category']! as String,
      readingMinutes: (json['readingMinutes']! as num).toInt(),
      publishedAt: DateTime.parse(json['publishedAt']! as String),
      imageAsset: json['image']! as String,
      keyPoints: _strings(json['keyPoints']),
      sections: _sections(json['sections']),
      funFact: json['funFact'] as String? ?? '',
      sources: _strings(json['sources']),
      relatedIds: _strings(json['relatedIds']),
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
      author: json['author$suffix'] as String? ?? '',
      category: json['category']! as String,
      readingMinutes: (json['readingMinutes']! as num).toInt(),
      publishedAt: DateTime.parse(json['publishedAt']! as String),
      imageAsset: json['image']! as String,
      keyPoints: _strings(json['keyPoints$suffix']),
      sections: _sections(json['sections$suffix']),
      funFact: json['funFact$suffix'] as String? ?? '',
      sources: _strings(json['sources$suffix']),
      relatedIds: _strings(json['relatedIds']),
    );
  }

  static List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return [for (final item in value) item.toString()];
  }

  static List<ArticleSection> _sections(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map)
          ArticleSection.fromJson(Map<String, dynamic>.from(item)),
    ];
  }
}
