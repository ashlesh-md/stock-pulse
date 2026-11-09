import 'package:market_server/src/time_buckets.dart' show istOffset;

/// A calendar date in India (no time, no zone). Value type.
class IstDate implements Comparable<IstDate> {
  const IstDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  DateTime get _utcMidnight => DateTime.utc(year, month, day);

  /// [DateTime.monday] … [DateTime.sunday].
  int get weekday => _utcMidnight.weekday;

  bool get isWeekend =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;

  IstDate addDays(int days) {
    final d = _utcMidnight.add(Duration(days: days));
    return IstDate(d.year, d.month, d.day);
  }

  bool isBefore(IstDate other) => compareTo(other) < 0;
  bool isAfter(IstDate other) => compareTo(other) > 0;

  @override
  int compareTo(IstDate other) => year != other.year
      ? year.compareTo(other.year)
      : month != other.month
      ? month.compareTo(other.month)
      : day.compareTo(other.day);

  @override
  bool operator ==(Object other) =>
      other is IstDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// `yyyy-mm-dd`, also the wire form (`tradingDay`, expiry codes).
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${_two(month)}-${_two(day)}';
}

/// IST = UTC+05:30 all year (no daylight saving).
abstract final class Ist {
  /// IST wall fields of [utc], as a UTC-flagged [DateTime] (read only its
  /// fields; it is not the same instant).
  static DateTime toIst(DateTime utc) => utc.toUtc().add(istOffset);

  /// The IST calendar date [utc] falls on.
  static IstDate dateOf(DateTime utc) {
    final t = toIst(utc);
    return IstDate(t.year, t.month, t.day);
  }

  /// The UTC instant of [h]:[m]:[s].[ms] IST on [date].
  static DateTime at(IstDate date, int h, int m, [int s = 0, int ms = 0]) =>
      DateTime.utc(
        date.year,
        date.month,
        date.day,
        h,
        m,
        s,
        ms,
      ).subtract(istOffset);

  /// ISO-8601 with the `+05:30` offset, e.g. `2026-11-06T10:02:11.000+05:30`.
  static String iso(DateTime utc) {
    final t = toIst(utc);
    return '${dateOf(utc)}T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}'
        '.${t.millisecond.toString().padLeft(3, '0')}+05:30';
  }
}

String _two(int v) => v.toString().padLeft(2, '0');
