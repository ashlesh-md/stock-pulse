import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/locales/en/common_strings_en.dart';

void main() {
  test('signs and rounding, with no "+-0.00"', () {
    expect(Fmt.percent(1.234), '+1.23%');
    expect(Fmt.percent(-1.235), '-1.24%');
    expect(Fmt.percent(-0.003), '+0.00%');
    expect(Fmt.percent(-0.0), '+0.00%');
    expect(Fmt.signed(-0.001), '+0.00');
    expect(Fmt.signed(-12.5), '-12.50');
  });

  test('Indian grouping and compact units', () {
    expect(Fmt.price(123456.7), '₹1,23,456.70');
    expect(Fmt.price(1234567.5), '₹12,34,567.50');
    expect(Fmt.integer(25000), '25,000');
    expect(Fmt.dayMonth(DateTime(2026, 11, 9)), '9 Nov');
    expect(Fmt.compact(450000), '4.50L');
    expect(Fmt.compact(23000000), '2.30Cr');
    expect(Fmt.compact(950), '950');
  });

  test('AppFormatter keys numbers and dates to its locale', () {
    final india = Fmt.forLocale('en_IN', currencySymbol: '₹');
    final us = Fmt.forLocale('en_US');
    expect(india.locale, 'en_IN');
    expect(india.number(1234567.5), '12,34,567.50');
    expect(us.number(1234567.5), '1,234,567.50');
    expect(india.price(1234567.5), '₹12,34,567.50');
    final date = DateTime(2026, 11, 9, 10, 42, 7);
    expect(india.time(date), '10:42:07');
    expect(india.shortTime(date), '10:42');
    expect(india.dayTime(date), '9 Nov 10:42');
    expect(india.date(date), '9 Nov 2026');
    expect(india.dayMonth(date), '9 Nov');
    expect(india.monthYear(date), 'Nov 26');
    expect(india.integer(25000), '25,000');
    expect(india.signed(-0.001), '+0.00');
    expect(india.percent(-0.003), '+0.00%');
    expect(india.compact(450000), '4.50L');
    expect(india.compact(23000000), '2.30Cr');
  });

  test('English plural units use a single plural rule', () {
    const common = CommonStringsEn();
    expect(common.lots(1), '1 lot');
    expect(common.lots(2), '2 lots');
  });
}
