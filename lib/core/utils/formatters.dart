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

  static String date(DateTime date, String localeLanguageCode) {
    final locale = localeLanguageCode == 'en' ? 'en_US' : 'id_ID';
    return DateFormat.yMMMMd(locale).format(date);
  }
}
