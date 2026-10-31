import 'package:intl/intl.dart';

/// Locale-aware number and date formatting.
///
/// Uses the active locale from [localeLanguageCode] ('id' or 'en').
abstract final class Formatters {
  static String currency(int amount, String localeLanguageCode) {
    final locale = localeLanguageCode == 'en' ? 'en_US' : 'id_ID';
    return NumberFormat.currency(
      locale: locale,
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  static String percent(double value, String localeLanguageCode) {
    final locale = localeLanguageCode == 'en' ? 'en_US' : 'id_ID';
    return NumberFormat.percentPattern(locale).format(value);
  }

  /// Plain number with the active locale's decimal separator.
  ///
  /// Used by P05 summary values such as report counts and waste kilograms.
  static String number(num value, String localeLanguageCode) {
    final locale = localeLanguageCode == 'en' ? 'en_US' : 'id_ID';
    return NumberFormat.decimalPattern(locale).format(value);
  }

  static String date(DateTime date, String localeLanguageCode) {
    final locale = localeLanguageCode == 'en' ? 'en_US' : 'id_ID';
    return DateFormat.yMMMMd(locale).format(date);
  }

  /// Date and time, for example `31 Okt 2026 14.05` in Indonesian.
  static String dateTime(DateTime date, String localeLanguageCode) {
    final locale = localeLanguageCode == 'en' ? 'en_US' : 'id_ID';
    return DateFormat.yMMMd(locale).add_Hm().format(date.toLocal());
  }
}
