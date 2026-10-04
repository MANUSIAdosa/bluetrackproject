import 'package:blue_track/core/localization/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every localized key has both Indonesian and English entries', () {
    final values = AppLocalizations.values;
    final idKeys = values['id']!.keys.toSet();
    final enKeys = values['en']!.keys.toSet();

    expect(
      enKeys.difference(idKeys),
      isEmpty,
      reason: 'Keys missing from the English map: ${enKeys.difference(idKeys)}',
    );
    expect(
      idKeys.difference(enKeys),
      isEmpty,
      reason: 'Keys missing from the Indonesian map: ${idKeys.difference(enKeys)}',
    );
  });

  test('no localized value is empty', () {
    for (final entry in AppLocalizations.values.entries) {
      for (final value in entry.value.entries) {
        expect(
          value.value.trim(),
          isNotEmpty,
          reason: 'Empty value for ${value.key} in ${entry.key}',
        );
      }
    }
  });

  test('placeholders match between locales', () {
    final id = AppLocalizations.values['id']!;
    final en = AppLocalizations.values['en']!;
    final placeholder = RegExp(r'\{\w+\}');

    for (final key in id.keys) {
      final idArgs = placeholder.allMatches(id[key]!).map((m) => m.group(0));
      final enArgs = placeholder.allMatches(en[key]!).map((m) => m.group(0));
      expect(
        idArgs.toSet(),
        enArgs.toSet(),
        reason: 'Placeholder mismatch for "$key"',
      );
    }
  });

  test('text() substitutes arguments', () {
    final localizations = AppLocalizations(const Locale('id'));
    final text = localizations.text('auth.otp.attemptsLeft', {'n': '2'});
    expect(text, contains('2'));
    expect(text, isNot(contains('{n}')));
  });
}
