import 'package:market_server/market_server.dart';
import 'package:test/test.dart';

/// Thu 12 Nov 2026 is a holiday in this fixture; so is Tue 17 Nov (FR-24:
/// a Tuesday-holiday expiry moves to Monday).
final cal = MarketCalendar(
  holidays: {const IstDate(2026, 11, 12), const IstDate(2026, 11, 17)},
  holidaySourceDate: 'test fixture',
);

DateTime ist(int d, int h, int m, [int s = 0, int ms = 0]) =>
    Ist.at(IstDate(2026, 11, d), h, m, s, ms);

void main() {
  group('trading days', () {
    test('Mon–Fri trade, weekends and holidays do not', () {
      expect(cal.isTradingDay(const IstDate(2026, 11, 9)), isTrue); // Mon
      expect(cal.isTradingDay(const IstDate(2026, 11, 7)), isFalse); // Sat
      expect(cal.isTradingDay(const IstDate(2026, 11, 8)), isFalse); // Sun
      expect(cal.isTradingDay(const IstDate(2026, 11, 12)), isFalse); // hol
    });

    test('next / previous trading day skip weekends and holidays', () {
      expect(
        cal.nextTradingDay(const IstDate(2026, 11, 6)),
        const IstDate(2026, 11, 9),
      );
      expect(
        cal.nextTradingDay(const IstDate(2026, 11, 11)),
        const IstDate(2026, 11, 13),
      );
      expect(
        cal.previousTradingDay(const IstDate(2026, 11, 9)),
        const IstDate(2026, 11, 6),
      );
      expect(
        cal.previousTradingDay(const IstDate(2026, 11, 18)),
        const IstDate(2026, 11, 16),
      );
    });
  });

  group('phaseAt (PRD §3.2: start inclusive, end exclusive)', () {
    test('edges on a trading day', () {
      expect(cal.phaseAt(ist(10, 8, 59, 59, 999)), MarketPhase.closed);
      expect(cal.phaseAt(ist(10, 9, 0)), MarketPhase.preOpen);
      expect(cal.phaseAt(ist(10, 9, 14, 59, 999)), MarketPhase.preOpen);
      expect(cal.phaseAt(ist(10, 9, 15)), MarketPhase.open);
      expect(cal.phaseAt(ist(10, 15, 29, 59, 999)), MarketPhase.open);
      expect(cal.phaseAt(ist(10, 15, 30)), MarketPhase.closed);
    });

    test('weekend and holiday are closed all day', () {
      expect(cal.phaseAt(ist(7, 10, 0)), MarketPhase.closed);
      expect(cal.phaseAt(ist(12, 10, 0)), MarketPhase.closed);
    });

    test('nextPhaseChangeAfter walks 09:00 → 09:15 → 15:30 → next day', () {
      expect(cal.nextPhaseChangeAfter(ist(10, 8, 0)), ist(10, 9, 0));
      expect(cal.nextPhaseChangeAfter(ist(10, 9, 0)), ist(10, 9, 15));
      expect(cal.nextPhaseChangeAfter(ist(10, 10, 0)), ist(10, 15, 30));
      expect(cal.nextPhaseChangeAfter(ist(11, 15, 30)), ist(13, 9, 0));
    });
  });

  group('expiries (FR-24)', () {
    test('NIFTY weekly: next two Tuesdays; a Tuesday holiday → Monday', () {
      final e = cal.expiriesFor('NIFTY', const IstDate(2026, 11, 11));
      expect(e.map((x) => x.code), ['2026-11-16', '2026-11-24']);
      expect(e.first.kind, ExpiryKind.weekly);
      expect(e.first.expiryAt, Ist.at(const IstDate(2026, 11, 16), 15, 30));
    });

    test('expiry day itself is listed', () {
      final e = cal.expiriesFor('NIFTY', const IstDate(2026, 11, 10));
      expect(e.first.code, '2026-11-10');
    });

    test('stocks monthly: last Tuesday of this and next month', () {
      final e = cal.expiriesFor('RELIANCE', const IstDate(2026, 11, 11));
      expect(e.map((x) => x.code), ['2026-11-24', '2026-12-29']);
      expect(e.first.kind, ExpiryKind.monthly);
    });

    test('after the last Tuesday, the monthly rolls to next month', () {
      final e = cal.expiriesFor('RELIANCE', const IstDate(2026, 11, 25));
      expect(e.map((x) => x.code), ['2026-12-29', '2027-01-26']);
    });

    test('adjustForHoliday repeats until a trading day', () {
      final c = MarketCalendar(
        holidays: {const IstDate(2026, 11, 17), const IstDate(2026, 11, 16)},
        holidaySourceDate: 'test',
      );
      expect(
        c.adjustForHoliday(const IstDate(2026, 11, 17)),
        const IstDate(2026, 11, 13),
      );
    });

    test('the built-in table carries its source date', () {
      final c = MarketCalendar.nse();
      expect(c.holidaySourceDate, isNotEmpty);
      expect(c.isTradingDay(const IstDate(2026, 1, 26)), isFalse);
    });
  });
}
