import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Locale-aware number and date formatting.
///
/// Uses the active locale from [localeLanguageCode] ('id' or 'en').
abstract final class Formatters {
  /// Whether the intl date symbols have been initialized. The local data
  /// covers every locale and initializes synchronously; the future is only a
  /// courtesy signature from intl.
  static bool _dateSymbolsReady = false;

  /// intl>=0.19 requires one explicit initialization before [DateFormat] can
  /// resolve localized symbols; without it non-`en` locales throw.
  static void _ensureDateSymbols() {
    if (_dateSymbolsReady) return;
    _dateSymbolsReady = true;
    unawaited(initializeDateFormatting());
  }

  /// Long calendar date (P08/P05 style, e.g. "24 Oktober 2026").
  static String date(DateTime date, String localeLanguageCode) {
    _ensureDateSymbols();
    final locale = _locale(localeLanguageCode);
    return DateFormat.yMMMMd(locale).format(date);
  }

  /// Short timestamp for one notification row. [now] is passed in so the
  /// grouping is testable; the page passes `DateTime.now()`.
  ///
  /// - Today: clock time ("15.03" / "3:15 PM")
  /// - This week (≤ 7 days, not today): weekday + time ("Selasa, 15.03")
  /// - Older: short date ("24 Okt 2026")
  static String notificationTime(
    DateTime time,
    String localeLanguageCode, {
    required DateTime now,
  }) {
    _ensureDateSymbols();
    final locale = _locale(localeLanguageCode);

    if (_timeTier(time, now) == NotificationTimeTier.today) {
      return DateFormat.jm(locale).format(time);
    }
    if (_timeTier(time, now) == NotificationTimeTier.thisWeek) {
      return DateFormat.EEEE(locale).add_jm().format(time);
    }
    return DateFormat.yMMMd(locale).format(time);
  }

  /// Which of the three time groups a notification belongs to, computed
  /// against [now] — never a stored category.
  static NotificationTimeTier timeTier(
    DateTime time, {
    required DateTime now,
  }) => _timeTier(time, now);

  static NotificationTimeTier _timeTier(DateTime time, DateTime now) {
    final dayOnly = DateTime(time.year, time.month, time.day);
    final todayOnly = DateTime(now.year, now.month, now.day);
    if (dayOnly == todayOnly) return NotificationTimeTier.today;
    final daysBetween = todayOnly.difference(dayOnly).inDays;
    return daysBetween <= 7
        ? NotificationTimeTier.thisWeek
        : NotificationTimeTier.older;
  }

  static String _locale(String localeLanguageCode) =>
      localeLanguageCode == 'en' ? 'en_US' : 'id_ID';

  static String currency(int amount, String localeLanguageCode) {
    _ensureDateSymbols();
    final locale = _locale(localeLanguageCode);
    return NumberFormat.currency(
      locale: locale,
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  static String percent(double value, String localeLanguageCode) {
    _ensureDateSymbols();
    final locale = _locale(localeLanguageCode);
    return NumberFormat.percentPattern(locale).format(value);
  }

  /// Plain number with the active locale's decimal separator.
  ///
  /// Used by P05 summary values such as report counts and waste kilograms.
  static String number(num value, String localeLanguageCode) {
    _ensureDateSymbols();
    final locale = _locale(localeLanguageCode);
    return NumberFormat.decimalPattern(locale).format(value);
  }

  /// Date and time, for example `31 Okt 2026 14.05` in Indonesian.
  static String dateTime(DateTime date, String localeLanguageCode) {
    _ensureDateSymbols();
    final locale = _locale(localeLanguageCode);
    return DateFormat.yMMMd(locale).add_Hm().format(date.toLocal());
  }
}

/// Groups the notification list falls into. Defined here because grouping and
/// formatting share the same "age against `now`" rule.
enum NotificationTimeTier { today, thisWeek, older }
