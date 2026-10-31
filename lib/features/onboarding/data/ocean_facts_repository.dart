import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

// TODO(P01-part-4): the slide copy of `assets/mock/ocean_facts.json` is a
// DRAFT awaiting Trevan's approval — edit the JSON there, nowhere else, so
// every slide text has exactly one source.

/// One onboarding ocean fact with its copy already resolved for a language.
class OnboardingSlide {
  const OnboardingSlide({
    required this.key,
    required this.title,
    required this.body,
  });

  /// Stable slide identifier, e.g. `slide1`.
  final String key;

  /// Short fact headline (<= 8 words per the onboarding rules).
  final String title;

  /// Exactly one explanatory sentence.
  final String body;
}

/// Reads the P01 slide copy from `assets/mock/ocean_facts.json`.
///
/// Every field exists in both supported languages (`titleId`/`titleEn`,
/// `bodyId`/`bodyEn`), so the language code decides which pair is returned.
class OceanFactsRepository {
  OceanFactsRepository._();

  static const _asset = 'assets/mock/ocean_facts.json';

  /// Test seam. The production loader reads the asset with REAL file IO,
  /// which fake-async widget tests cannot pump deterministically (the Future
  /// they start inside a build never lands on later testWidgets). Tests
  /// override this with canned slides; production always keeps the default.
  static Future<List<OnboardingSlide>> Function(String languageCode) loader =
      loadFromAsset;

  /// Entry point the page uses.
  static Future<List<OnboardingSlide>> load(String languageCode) =>
      loader(languageCode);

  /// Reads the three slides for [languageCode] (`'id'` or `'en'`; any other
  /// code falls back to Indonesian, the app's primary language).
  static Future<List<OnboardingSlide>> loadFromAsset(String languageCode) async {
    final raw = await rootBundle.loadString(_asset);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final slides = map['slides']! as List<dynamic>;

    final titleField = 'title${_suffix(languageCode)}';
    final bodyField = 'body${_suffix(languageCode)}';

    return [
      for (final slide in slides.cast<Map<String, dynamic>>())
        OnboardingSlide(
          key: slide['key']! as String,
          title: slide[titleField]! as String,
          body: slide[bodyField]! as String,
        ),
    ];
  }

  static String _suffix(String languageCode) =>
      languageCode == 'en' ? 'En' : 'Id';
}
