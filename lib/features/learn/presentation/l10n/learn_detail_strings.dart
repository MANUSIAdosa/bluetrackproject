import 'package:flutter/widgets.dart';

/// Feature-local copy for the P16 article detail extras.
///
/// The page chrome is normally localized through [AppLocalizations], but this
/// change is scoped to `features/learn` and `education.json`, so the new labels
/// live with the feature instead of modifying the shared localization file.
class LearnDetailStrings {
  const LearnDetailStrings._(this._values);

  static const _id = LearnDetailStrings._({
    'keyPoints': 'Poin Penting',
    'funFact': 'Tahukah Anda?',
    'sources': 'Sumber',
    'related': 'Artikel Terkait',
    'textSize': 'Ukuran teks',
    'small': 'Kecil',
    'medium': 'Sedang',
    'large': 'Besar',
    'relatedFailed': 'Artikel terkait gagal dibuka.',
  });

  static const _en = LearnDetailStrings._({
    'keyPoints': 'Key Points',
    'funFact': 'Did you know?',
    'sources': 'Sources',
    'related': 'Related Articles',
    'textSize': 'Text size',
    'small': 'Small',
    'medium': 'Medium',
    'large': 'Large',
    'relatedFailed': 'Could not open the related article.',
  });

  static LearnDetailStrings of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en' ? _en : _id;

  final Map<String, String> _values;

  String get keyPoints => _values['keyPoints']!;
  String get funFact => _values['funFact']!;
  String get sources => _values['sources']!;
  String get related => _values['related']!;
  String get textSize => _values['textSize']!;
  String get small => _values['small']!;
  String get medium => _values['medium']!;
  String get large => _values['large']!;
  String get relatedFailed => _values['relatedFailed']!;
}
