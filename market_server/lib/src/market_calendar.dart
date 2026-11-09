import 'package:market_server/src/ist.dart';

/// Trading phase of the market at a market-time instant.
enum MarketPhase { preOpen, open, closed }

/// Weekly (NIFTY) or monthly (stocks) option expiry.
enum ExpiryKind { weekly, monthly }

/// One listed expiry: its IST date and the settlement instant (15:30 IST).
class ListedExpiry {
  const ListedExpiry({
    required this.date,
    required this.expiryAt,
    required this.kind,
  });

  final IstDate date;
  final DateTime expiryAt;
  final ExpiryKind kind;

  /// Wire code, e.g. `2026-11-10`.
  String get code => date.toString();

  @override
  bool operator ==(Object other) =>
      other is ListedExpiry && other.date == date && other.kind == kind;

  @override
  int get hashCode => Object.hash(date, kind);

  @override
  String toString() => 'ListedExpiry($code, ${kind.name})';
}

/// Where [nseHolidays2026] came from. Simulator data: check it against the
/// exchange's published list before relying on any date.
const nseHolidaySourceDate =
    'NSE 2026 trading holiday list, entered 2026-11-07';

/// NSE trading holidays 2026 on weekdays, the one holiday config table.
/// Tests pass their own set.
final nseHolidays2026 = Set<IstDate>.unmodifiable(const [
  IstDate(2026, 1, 26), // Republic Day
  IstDate(2026, 3, 3), // Holi
  IstDate(2026, 3, 26), // Shri Ram Navami
  IstDate(2026, 3, 31), // Shri Mahavir Jayanti
  IstDate(2026, 4, 3), // Good Friday
  IstDate(2026, 4, 14), // Dr. Baba Saheb Ambedkar Jayanti
  IstDate(2026, 5, 1), // Maharashtra Day
  IstDate(2026, 5, 28), // Bakri Id
  IstDate(2026, 6, 26), // Muharram
  IstDate(2026, 9, 14), // Ganesh Chaturthi
  IstDate(2026, 10, 2), // Mahatma Gandhi Jayanti
  IstDate(2026, 10, 20), // Dussehra
  IstDate(2026, 11, 10), // Diwali Balipratipada
  IstDate(2026, 11, 24), // Guru Nanak Jayanti
  IstDate(2026, 12, 25), // Christmas
]);

/// Pure calendar maths: phases, trading days, expiries. No clock inside.
class MarketCalendar {
  MarketCalendar({
    required Set<IstDate> holidays,
    required this.holidaySourceDate,
  }) : holidays = Set.unmodifiable(holidays);

  /// The built-in NSE table.
  factory MarketCalendar.nse() => MarketCalendar(
    holidays: nseHolidays2026,
    holidaySourceDate: nseHolidaySourceDate,
  );

  final Set<IstDate> holidays;
  final String holidaySourceDate;

  /// Mon–Fri and not a holiday.
  bool isTradingDay(IstDate d) => !d.isWeekend && !holidays.contains(d);

  /// [09:00, 09:15) preOpen · [09:15, 15:30) open · else closed.
  MarketPhase phaseAt(DateTime utc) {
    final day = Ist.dateOf(utc);
    if (!isTradingDay(day)) return MarketPhase.closed;
    if (utc.isBefore(Ist.at(day, 9, 0))) return MarketPhase.closed;
    if (utc.isBefore(Ist.at(day, 9, 15))) return MarketPhase.preOpen;
    if (utc.isBefore(Ist.at(day, 15, 30))) return MarketPhase.open;
    return MarketPhase.closed;
  }

  /// The next 09:00 / 09:15 / 15:30 on a trading day strictly after [utc].
  /// Null only if no trading day exists in the next year.
  DateTime? nextPhaseChangeAfter(DateTime utc) {
    var day = Ist.dateOf(utc);
    for (var i = 0; i < 366; i++, day = day.addDays(1)) {
      if (!isTradingDay(day)) continue;
      for (final (h, m) in const [(9, 0), (9, 15), (15, 30)]) {
        final at = Ist.at(day, h, m);
        if (at.isAfter(utc)) return at;
      }
    }
    return null;
  }

  IstDate nextTradingDay(IstDate d) {
    var x = d.addDays(1);
    while (!isTradingDay(x)) {
      x = x.addDays(1);
    }
    return x;
  }

  IstDate previousTradingDay(IstDate d) {
    var x = d.addDays(-1);
    while (!isTradingDay(x)) {
      x = x.addDays(-1);
    }
    return x;
  }

  /// A non-trading expiry date moves to the previous trading day (repeat).
  IstDate adjustForHoliday(IstDate expiry) =>
      isTradingDay(expiry) ? expiry : previousTradingDay(expiry);

  /// The first [count] expiries on or after [day]. NIFTY lists weekly
  /// Tuesdays; every other underlying lists the last Tuesday of the month.
  /// [kind] overrides that default.
  List<ListedExpiry> expiriesFor(
    String underlying,
    IstDate day, {
    int count = 2,
    ExpiryKind? kind,
  }) {
    final k =
        kind ??
        (underlying == 'NIFTY' ? ExpiryKind.weekly : ExpiryKind.monthly);
    final out = <ListedExpiry>[];
    // Candidates start from [day]: holiday adjustment only moves a date
    // earlier, so an earlier candidate can never land on or after [day].
    final candidates = k == ExpiryKind.weekly
        ? _tuesdaysFrom(day)
        : _lastTuesdaysFrom(day);
    for (final candidate in candidates) {
      final date = adjustForHoliday(candidate);
      if (date.isBefore(day)) continue;
      out.add(
        ListedExpiry(date: date, expiryAt: Ist.at(date, 15, 30), kind: k),
      );
      if (out.length == count) break;
    }
    return out;
  }

  static Iterable<IstDate> _tuesdaysFrom(IstDate from) sync* {
    var d = from.addDays((DateTime.tuesday - from.weekday) % 7);
    while (true) {
      yield d;
      d = d.addDays(7);
    }
  }

  static Iterable<IstDate> _lastTuesdaysFrom(IstDate from) sync* {
    var year = from.year;
    var month = from.month;
    while (true) {
      final last = DateTime.utc(year, month + 1, 0); // last day of month
      final back = (last.weekday - DateTime.tuesday) % 7;
      final d = IstDate(last.year, last.month, last.day - back);
      if (!d.isBefore(from)) yield d;
      if (++month > 12) {
        month = 1;
        year++;
      }
    }
  }
}
