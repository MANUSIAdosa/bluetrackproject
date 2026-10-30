import 'package:intl/intl.dart';

/// Locale-aware formatting helpers shared by the P04 report widgets.
///
/// Keeping these outside the widgets means no widget contains its own number
/// or date pattern, and the active language always decides the separators.
abstract final class P04Format {
  static String _locale(String lang) => lang == 'en' ? 'en_US' : 'id_ID';

  /// Formats a possibly fractional metric, omitting a trailing `.0`.
  static String number(double value, String lang) {
    final pattern = NumberFormat.decimalPattern(_locale(lang));
    if (value == value.roundToDouble()) {
      return pattern.format(value.toInt());
    }
    return pattern.format(value);
  }

  /// Formats a whole number such as a report count.
  static String integer(int value, String lang) =>
      NumberFormat.decimalPattern(_locale(lang)).format(value);

  /// Rating with exactly one decimal and the locale separator, for example
  /// `4,3` in Indonesian and `4.3` in English.
  static String rating(double value, String lang) =>
      NumberFormat('0.0', _locale(lang)).format(value);

  /// Short month label for the chart x-axis, for example `Okt` / `Oct`.
  static String monthShort(DateTime date, String lang) =>
      DateFormat.MMM(_locale(lang)).format(date);

  /// Month and year for tooltips, for example `Okt 2026`.
  static String monthYear(DateTime date, String lang) =>
      DateFormat.yMMM(_locale(lang)).format(date);

  /// Date shown in the report list.
  static String date(DateTime date, String lang) =>
      DateFormat.yMMMMd(_locale(lang)).format(date);

  /// Date and time shown in the report detail sheet.
  static String dateTime(DateTime date, String lang) =>
      DateFormat.yMMMMd(_locale(lang)).add_Hm().format(date);
}
