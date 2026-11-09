import 'dart:async';
import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:test/test.dart';

final cal = MarketCalendar(holidays: const {}, holidaySourceDate: 'test');
const tue = IstDate(2026, 11, 10);
const wed = IstDate(2026, 11, 11);

MarketEngine engineAt(DateTime market, {int intradayDays = 1}) => MarketEngine(
  instruments,
  random: Random(11),
  marketClock: FakeMarketClock(
    wallStart: DateTime.utc(2026, 11),
    marketStart: market,
  ),
  calendar: cal,
  intradayDays: intradayDays,
  dailyDays: intradayDays == 0 ? 0 : 20,
);

DateTime istMidnight(IstDate d) => Ist.at(d, 0, 0);

void main() {
  test('rollDay starts a flat daily candle at the last price', () {
    final e = engineAt(Ist.at(tue, 15, 0));
    final tcs = e['TCS']!..iep = 1;
    final close = tcs.ltp;

    e.rollDay(BoundaryEvent(BoundaryKind.dayRoll, wed, Ist.at(wed, 9, 0)));

    expect(tcs.iep, isNull);
    expect(tcs.today.start, istMidnight(wed));
    expect([tcs.open, tcs.high, tcs.low, tcs.volume], [close, close, close, 0]);
    expect(tcs.prevClose, close);
  });

  test('openMarket adds today at the IEP when today has no candle', () {
    final e = engineAt(Ist.at(tue, 15, 0));
    final tcs = e['TCS']!..iep = 1234.5;

    e.openMarket(BoundaryEvent(BoundaryKind.open, wed, Ist.at(wed, 9, 15)));

    expect(tcs.iep, isNull);
    expect(tcs.ltp, 1234.5);
    expect(tcs.today.start, istMidnight(wed));
    expect(tcs.open, 1234.5);
  });

  test('openMarket resets an untraded candle of today to the IEP', () {
    final e = engineAt(Ist.at(tue, 15, 0));
    final tcs = e['TCS']!;
    e.rollDay(BoundaryEvent(BoundaryKind.dayRoll, wed, Ist.at(wed, 9, 0)));
    tcs.iep = 999.5;

    e.openMarket(BoundaryEvent(BoundaryKind.open, wed, Ist.at(wed, 9, 15)));

    expect(
      [tcs.open, tcs.high, tcs.low, tcs.today.close],
      [999.5, 999.5, 999.5, 999.5],
    );
  });

  test('an instrument with no history starts flat at its base price', () {
    final e = engineAt(istMidnight(tue), intradayDays: 0);
    final tcs = e['TCS']!;
    expect(tcs.minutes, isEmpty);
    expect(tcs.daily, hasLength(1));
    expect(tcs.ltp, tcs.instrument.basePrice);
    expect(tcs.open, tcs.instrument.basePrice);
  });

  test('candles stop at the `to` bound', () {
    final e = engineAt(Ist.at(tue, 15, 0));
    final to = Ist.at(tue, 10, 0);
    final out = e.candles('TCS', const Duration(minutes: 5), to: to);
    expect(out, isNotEmpty);
    expect(out.every((c) => !c.start.isAfter(to)), isTrue);
  });

  test('change and changePercent are measured from prevClose', () {
    final tcs = engineAt(Ist.at(tue, 15, 0))['TCS']!;
    tcs.ltp = tcs.prevClose * 1.1;
    expect(tcs.kind, InstrumentKind.equity);
    expect(tcs.change, closeTo(tcs.prevClose * 0.1, 1e-9));
    expect(tcs.changePercent, closeTo(10, 1e-9));
  });

  test('start runs step on the tick timer until stop', () async {
    final e = MarketEngine(
      instruments,
      clock: () => DateTime.utc(2026, 11, 10, 6),
      tickInterval: const Duration(milliseconds: 5),
      intradayDays: 0,
      dailyDays: 0,
    );
    final first = e.ticks.first;
    e.start();
    final traded = await first.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(Duration.zero);
    await e.stop();
    expect(traded, isNotEmpty);
  });

  test('a default server builds a phased engine on the NSE calendar', () async {
    final server = MarketServer(random: Random(1))..start();
    expect(server.engine.calendar, same(server.calendar));
    expect(server.engine.scheduler, same(server.scheduler));
    await server.close();
  });
}
