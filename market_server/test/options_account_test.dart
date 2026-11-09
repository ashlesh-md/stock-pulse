import 'dart:math';
import 'package:market_server/market_server.dart';
import 'package:test/test.dart';

void main() {
  late MarketServer server;
  setUp(() {
    final clock = FakeMarketClock(
      wallStart: DateTime.utc(2026, 11, 9, 5),
      marketStart: DateTime.utc(2026, 11, 9, 5),
    );
    server = MarketServer(
      clock: clock,
      engine: MarketEngine(
        instruments,
        random: Random(2),
        clock: clock.marketNow,
        intradayDays: 1,
        dailyDays: 2,
      ),
    );
  });
  tearDown(() => server.close());
  test(
    'chain fixes 41 strikes around previous close and lists tradable contracts',
    () {
      final expiry = server.options.expiries('NIFTY').first['code']! as String;
      final first = server.options.chain('NIFTY', expiry);
      expect(first['strikes'], hasLength(41));
      final rows = first['rows']! as List;
      expect(rows, hasLength(41));
      final cell = (rows[20] as Map)['ce'] as Map;
      final stock = server.engine[cell['contractId']! as String]!;
      expect(stock.instrument.lotSize, 65);
      expect(stock.instrument.tradable, isTrue);
      expect(stock.ltp, greaterThanOrEqualTo(.05));
      server.engine['NIFTY']!.ltp += 150;
      expect(
        server.options.chain('NIFTY', expiry)['strikes'],
        first['strikes'],
      );
      final order = server.broker.place(
        symbol: stock.id,
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 1,
        lots: 1,
        product: ProductType.nrml,
        idempotencyKey: 'option-1',
      );
      expect(order.quantity, 65);
      expect(order.status, OrderStatus.complete);
      expect(server.broker.byClientKey('option-1'), same(order));
    },
  );
  test(
    'S-23: option prices stay fixed through pre-open IEP movement',
    () async {
      final marketTime = DateTime.utc(2026, 11, 10, 3, 30);
      final clock = FakeMarketClock(
        wallStart: marketTime,
        marketStart: marketTime,
      );
      final calendar = MarketCalendar(
        holidays: const {},
        holidaySourceDate: 'test',
      );
      final testServer = MarketServer(
        clock: clock,
        calendar: calendar,
        random: Random(8),
      );
      final expiry =
          testServer.options.expiries('NIFTY').first['code']! as String;
      final initial = testServer.options.chain('NIFTY', expiry);
      final row = (initial['rows']! as List)[20] as Map;
      final call = (row['ce']! as Map)['contractId']! as String;
      final optionPrice = testServer.engine[call]!.ltp;

      for (var i = 0; i < 30; i++) {
        testServer.engine.step();
      }
      expect(testServer.engine.phase, MarketPhase.preOpen);
      expect(testServer.engine['TCS']!.iep, isNotNull);
      testServer.options.chain('NIFTY', expiry);
      expect(testServer.engine[call]!.ltp, optionPrice);
      await testServer.close();
    },
  );
  test('S-49: load mode emits every equity and option on each step', () async {
    final marketTime = DateTime.utc(2026, 11, 9, 5);
    final clock = FakeMarketClock(
      wallStart: marketTime,
      marketStart: marketTime,
    );
    final calendar = MarketCalendar(
      holidays: const {},
      holidaySourceDate: 'test',
    );
    final testServer = MarketServer(
      clock: clock,
      calendar: calendar,
      random: Random(49),
      load: true,
    );
    final expiry =
        testServer.options.expiries('NIFTY').first['code']! as String;
    testServer.options.chain('NIFTY', expiry);
    final equityIds = testServer.engine.stocks
        .where((stock) => stock.instrument.kind == InstrumentKind.equity)
        .map((stock) => stock.id)
        .toSet();
    final optionIds = testServer.engine.stocks
        .where((stock) => stock.instrument.kind == InstrumentKind.option)
        .map((stock) => stock.id)
        .toSet();
    final tick = testServer.engine.ticks.first;

    testServer.engine.step();

    final changed = await tick;
    expect(testServer.engine.load, isTrue);
    expect(changed, containsAll(equityIds));
    expect(changed, containsAll(optionIds));
    await testServer.close();
  });
  test(
    'broker keeps products separate and rejects off tick prices and naked delivery sales',
    () {
      server.broker.place(
        symbol: 'RELIANCE',
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 1,
        product: ProductType.cnc,
      );
      server.broker.place(
        symbol: 'RELIANCE',
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 1,
      );
      expect(server.broker.positions, hasLength(2));
      expect(
        () => server.broker.place(
          symbol: 'RELIANCE',
          side: OrderSide.sell,
          type: OrderType.market,
          quantity: 2,
          product: ProductType.cnc,
        ),
        throwsA(
          isA<OrderRejection>().having(
            (e) => e.code,
            'code',
            'insufficient_holdings',
          ),
        ),
      );
      expect(
        () => server.broker.place(
          symbol: 'TCS',
          side: OrderSide.buy,
          type: OrderType.limit,
          quantity: 1,
          limitPrice: server.engine['TCS']!.ltp + .03,
        ),
        throwsA(
          isA<OrderRejection>().having((e) => e.code, 'code', 'invalid_tick'),
        ),
      );
    },
  );
}
