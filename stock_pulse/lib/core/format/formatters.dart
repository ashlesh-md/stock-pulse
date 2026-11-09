import 'dart:async';

import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:intl/intl.dart';

/// Locale-keyed number and date formatting used by the application.
final class AppFormatter {
  factory AppFormatter(String locale, {String? currencySymbol}) {
    final canonicalLocale = Intl.canonicalizedLocale(locale);
    // This populates Intl's local symbol tables synchronously before the
    // resolved Future is returned, so formatters remain cheap to construct.
    unawaited(initializeDateFormatting(canonicalLocale));
    return AppFormatter._(canonicalLocale, currencySymbol);
  }

  AppFormatter._(this.locale, String? currencySymbol)
    : _price = NumberFormat.currency(
        locale: locale,
        symbol: currencySymbol,
        decimalDigits: 2,
      ),
      _plain = NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: 2,
      ),
      _integer = NumberFormat.decimalPattern(locale),
      _time = DateFormat('HH:mm:ss', locale),
      _shortTime = DateFormat('HH:mm', locale),
      _dayTime = DateFormat('d MMM HH:mm', locale),
      _date = DateFormat('d MMM yyyy', locale),
      _dayMonth = DateFormat('d MMM', locale),
      _monthYear = DateFormat('MMM yy', locale);

  final String locale;
  final NumberFormat _price;
  final NumberFormat _plain;
  final NumberFormat _integer;
  final DateFormat _time;
  final DateFormat _shortTime;
  final DateFormat _dayTime;
  final DateFormat _date;
  final DateFormat _dayMonth;
  final DateFormat _monthYear;

  String price(double value) => _price.format(value);
  String number(double value) => _plain.format(value);
  String integer(num value) => _integer.format(value);

  /// +12.35 or -4.10, with locale-specific decimal punctuation.
  String signed(double value) {
    final rounded = _round2(value);
    return '${rounded >= 0 ? '+' : ''}${_plain.format(rounded)}';
  }

  /// +1.25%, with locale-specific decimal punctuation.
  String percent(double value) {
    final rounded = _round2(value);
    return '${rounded >= 0 ? '+' : ''}${_plain.format(rounded)}%';
  }

  /// 950 → 950, 12,500 → 12.5K, 4,50,000 → 4.5L, 2,30,00,000 → 2.3Cr.
  String compact(num value) {
    if (value >= 1e7) return '${(value / 1e7).toStringAsFixed(2)}Cr';
    if (value >= 1e5) return '${(value / 1e5).toStringAsFixed(2)}L';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String time(DateTime value) => _time.format(value.toLocal());
  String shortTime(DateTime value) => _shortTime.format(value.toLocal());
  String dayTime(DateTime value) => _dayTime.format(value.toLocal());
  String date(DateTime value) => _date.format(value.toLocal());
  String dayMonth(DateTime value) => _dayMonth.format(value.toLocal());
  String monthYear(DateTime value) => _monthYear.format(value.toLocal());
}

/// Existing app call sites use the default Indian locale through this facade.
/// New locale-aware surfaces should obtain an [AppFormatter] for their locale.
abstract final class Fmt {
  static final _default = AppFormatter('en_IN', currencySymbol: '₹');

  static AppFormatter forLocale(String locale, {String? currencySymbol}) =>
      AppFormatter(locale, currencySymbol: currencySymbol);

  static String price(double value) => _default.price(value);
  static String number(double value) => _default.number(value);
  static String integer(num value) => _default.integer(value);
  static String signed(double value) => _default.signed(value);
  static String percent(double value) => _default.percent(value);
  static String compact(num value) => _default.compact(value);
  static String time(DateTime value) => _default.time(value);
  static String shortTime(DateTime value) => _default.shortTime(value);
  static String dayTime(DateTime value) => _default.dayTime(value);
  static String date(DateTime value) => _default.date(value);
  static String dayMonth(DateTime value) => _default.dayMonth(value);
  static String monthYear(DateTime value) => _default.monthYear(value);
}

double _round2(double value) {
  final rounded = (value * 100).roundToDouble() / 100;
  return rounded == 0 ? 0.0 : rounded;
}
