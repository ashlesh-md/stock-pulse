import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:test/test.dart';

final cal = MarketCalendar(holidays: const {}, holidaySourceDate: 'test');
const tue = IstDate(2026, 11, 10);

({MarketEngine engine, FakeMarketClock clock}) engineAt(
  DateTime market, {
  bool load = false,
}) {
  final clock = FakeMarketClock(
    wallStart: DateTime.utc(2026, 11),
    marketStart: market,
  );
  final engine = MarketEngine(
    instruments,
    random: Random(7),
    marketClock: clock,
    calendar: cal,
    load: load,
    intradayDays: 1,
    dailyDays: 30,
  );
  return (engine: engine, clock: clock);
}

void main() {
  test('closed: no ticks, prices unchanged (AC4)', () {
    final e = engineAt(Ist.at(tue, 16, 0)).engine;
    final ticks = <Set<String>>[];
    e.ticks.listen(ticks.add);
    final before = {for (final s in e.stocks) s.instrument.symbol: s.ltp};
    for (var i = 0; i < 20; i++) {
      e.step();
    }
    expect(ticks, isEmpty);
    expect(e.phase, MarketPhase.closed);
    for (final s in e.stocks) {
      expect(s.ltp, before[s.instrument.symbol]);
    }
  });

  test('pre-open: IEP only, no trades, no volume, no candles (AC4)', () {
    final e = engineAt(Ist.at(tue, 9, 5)).engine;
    final ticks = <Set<String>>[];
    e.ticks.listen(ticks.add);
    final reliance = e['RELIANCE']!;
    final ltp = reliance.ltp;
    final volume = reliance.volume;
    final minutes = reliance.minutes.length;
    final lastTrade = reliance.lastTradeTime;
    for (var i = 0; i < 40; i++) {
      e.step();
    }
    expect(ticks, isNotEmpty);
    expect(reliance.iep, isNotNull);
    expect(reliance.ltp, ltp);
    expect(reliance.volume, volume);
    expect(reliance.minutes, hasLength(minutes));
    expect(reliance.lastTradeTime, lastTrade);

    final json = e.quoteJson(reliance, FeedMode.quote);
    expect(json['iep'], isTrue);
    expect(json['ltp'], reliance.iep);
  });

  test('open boundary: IEP becomes the open price, then trading resumes', () {
    final r = engineAt(Ist.at(tue, 9, 10));
    final e = r.engine;
    for (var i = 0; i < 40; i++) {
      e.step();
    }
    final s = e['RELIANCE']!;
    final iep = s.iep!;
    r.clock.jumpTo(Ist.at(tue, 9, 15));
    e.openMarket(BoundaryEvent(BoundaryKind.open, tue, Ist.at(tue, 9, 15)));
    expect(s.iep, isNull);
    expect(s.ltp, iep);
    expect(s.open, iep);
    expect(e.quoteJson(s, FeedMode.quote).containsKey('iep'), isFalse);

    final ticks = <Set<String>>[];
    e.ticks.listen(ticks.add);
    e.step();
    expect(e.phase, MarketPhase.open);
    expect(ticks.single, isNotEmpty);
  });

  test('pre-open limit order fills on the first open tick', () async {
    final r = engineAt(Ist.at(tue, 9, 10), load: true);
    final broker = Broker(r.engine, clock: r.clock.marketNow);
    final stock = r.engine['RELIANCE']!;
    r.engine.step();
    final upperBand = stock.instrument.bandFor(stock.prevClose)!.high;
    final queued = broker.place(
      symbol: 'RELIANCE',
      side: OrderSide.buy,
      type: OrderType.limit,
      quantity: 1,
      product: ProductType.cnc,
      limitPrice: upperBand,
    );
    final queuedVersion = queued.version;
    expect(queued.status, OrderStatus.queued);

    r.clock.jumpTo(Ist.at(tue, 9, 15));
    r.engine.openMarket(
      BoundaryEvent(BoundaryKind.open, tue, Ist.at(tue, 9, 15)),
    );
    r.engine.step();

    expect(queued.status, OrderStatus.complete);
    expect(queued.version, greaterThan(queuedVersion));
    await broker.dispose();
    await r.engine.stop();
    await r.clock.close();
  });

  test('candles and trade times use market time', () {
    final r = engineAt(Ist.at(tue, 11, 0));
    final s = r.engine['TCS']!;
    while (s.lastTradeTime != r.clock.marketNow()) {
      r.engine.step();
    }
    expect(s.minutes.last.start, Ist.at(tue, 11, 0));
  });

  test('without a calendar the engine trades 24/7 (v1)', () {
    final e = MarketEngine(
      instruments,
      random: Random(1),
      clock: () => Ist.at(tue, 23, 0),
      intradayDays: 1,
      dailyDays: 10,
    );
    final ticks = <Set<String>>[];
    e.ticks.listen(ticks.add);
    e.step();
    expect(ticks, isNotEmpty);
    expect(e.phase, MarketPhase.open);
  });
}
