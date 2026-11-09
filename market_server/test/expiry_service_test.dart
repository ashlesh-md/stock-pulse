import 'dart:math';
import 'package:market_server/market_server.dart';
import 'package:test/test.dart';

void main() {
  test('15:20 square-off books realised MIS P&L and preserves CNC', () async {
    const date = IstDate(2026, 11, 10);
    final clock = FakeMarketClock(
      wallStart: DateTime.utc(2026, 11, 10, 4),
      marketStart: Ist.at(date, 10, 0),
    );
    final server = MarketServer(
      clock: clock,
      calendar: MarketCalendar(holidays: const {}, holidaySourceDate: 'test'),
      engine: MarketEngine(
        instruments,
        clock: clock.marketNow,
        random: Random(2),
        intradayDays: 1,
        dailyDays: 2,
      ),
    );
    addTearDown(server.close);
    final stock = server.engine['TCS']!;
    stock.ltp = 1000;
    final misEntry = server.broker.place(
      symbol: 'TCS',
      side: OrderSide.buy,
      type: OrderType.market,
      quantity: 10,
    );
    server.broker.place(
      symbol: 'TCS',
      side: OrderSide.buy,
      type: OrderType.market,
      product: ProductType.cnc,
      quantity: 5,
    );
    stock.ltp = misEntry.averagePrice! + 650;

    server.expiryService.squareOff(
      BoundaryEvent(BoundaryKind.squareOff, date, Ist.at(date, 15, 20)),
    );
    final mis = server.broker.positions.singleWhere(
      (position) => position.product == ProductType.mis,
    );
    final cnc = server.broker.positions.singleWhere(
      (position) => position.product == ProductType.cnc,
    );
    expect(mis.quantity, 0);
    expect(mis.realizedPnl, 6500);
    expect(cnc.quantity, 5);
    expect(
      server.broker.orders.any(
        (order) =>
            order.product == ProductType.mis &&
            order.reason == 'auto_square_off' &&
            order.status == OrderStatus.complete,
      ),
      isTrue,
    );

    server.expiryService.settle(
      BoundaryEvent(BoundaryKind.settle, date, Ist.at(date, 15, 30)),
    );
    expect(
      server.broker.positions
          .singleWhere((position) => position.product == ProductType.mis)
          .realizedPnl,
      6500,
    );
  });

  test(
    'expiry settles intrinsic once and square off leaves carry positions',
    () async {
      const date = IstDate(2026, 11, 10);
      final clock = FakeMarketClock(
        wallStart: DateTime.utc(2026, 11, 10, 4),
        marketStart: Ist.at(date, 10, 0),
      );
      final server = MarketServer(
        clock: clock,
        calendar: MarketCalendar(holidays: const {}, holidaySourceDate: 'test'),
        engine: MarketEngine(
          instruments,
          clock: clock.marketNow,
          random: Random(2),
          intradayDays: 1,
          dailyDays: 2,
        ),
      );
      addTearDown(server.close);
      final chain = server.options.chain('NIFTY', '2026-11-10');
      final atm = chain['atm']! as int;
      final row = (chain['rows']! as List)
          .cast<Map<String, Object?>>()
          .firstWhere((r) => r['strike'] == atm);
      final id = (row['ce']! as Map<String, Object?>)['contractId']! as String;
      final settlements = <(String, Map<String, Object?>)>[];
      final settlementSub = server.account.events.listen(settlements.add);
      addTearDown(settlementSub.cancel);
      server.broker.place(
        symbol: id,
        side: OrderSide.buy,
        type: OrderType.market,
        product: ProductType.nrml,
        quantity: 1,
        lots: 1,
      );
      server.engine['NIFTY']!.ltp = atm + 100;
      clock.jumpTo(Ist.at(date, 15, 30));
      server.expiryService.settle(
        BoundaryEvent(BoundaryKind.settle, date, Ist.at(date, 15, 30)),
      );
      expect(
        server.broker.positions.where((p) => p.symbol == id).single.quantity,
        0,
      );
      final count = server.broker.orders.length;
      server.expiryService.settle(
        BoundaryEvent(BoundaryKind.settle, date, Ist.at(date, 15, 30)),
      );
      expect(server.broker.orders, hasLength(count));
      expect(server.broker.orders.first.averagePrice, 100);
      final settlementFrames = settlements
          .where((event) => event.$1 == 'settlement')
          .toList();
      expect(settlementFrames, hasLength(1));
      expect(settlementFrames.single.$2['settlePrice'], 100);
      expect(server.options.chain('NIFTY', '2026-11-10')['status'], 'expired');
      server.broker.place(
        symbol: 'TCS',
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 1,
      );
      server.broker.place(
        symbol: 'RELIANCE',
        side: OrderSide.buy,
        type: OrderType.market,
        product: ProductType.cnc,
        quantity: 1,
      );
      final carryExpiry =
          server.options
                  .expiries('NIFTY')
                  .firstWhere(
                    (expiry) => expiry['code'] != '2026-11-10',
                  )['code']!
              as String;
      final carryChain = server.options.chain('NIFTY', carryExpiry);
      final carryRow = (carryChain['rows']! as List)
          .cast<Map<String, Object?>>()
          .first;
      final carryOption =
          (carryRow['ce']! as Map<String, Object?>)['contractId']! as String;
      server.broker.place(
        symbol: carryOption,
        side: OrderSide.buy,
        type: OrderType.market,
        product: ProductType.nrml,
        quantity: 1,
        lots: 1,
      );
      final orderFrames = <Order>[];
      final updateSub = server.broker.updates.listen(orderFrames.add);
      addTearDown(updateSub.cancel);
      server.expiryService.squareOff(
        BoundaryEvent(BoundaryKind.squareOff, date, Ist.at(date, 15, 20)),
      );
      expect(
        server.broker.positions.where((p) => p.symbol == 'TCS').single.quantity,
        0,
      );
      expect(
        server.broker.positions
            .where((p) => p.symbol == 'RELIANCE')
            .single
            .quantity,
        1,
      );
      expect(
        server.broker.positions
            .where((p) => p.symbol == carryOption)
            .single
            .quantity,
        65,
      );
      expect(
        orderFrames.any(
          (order) =>
              order.reason == 'auto_square_off' &&
              order.status == OrderStatus.complete,
        ),
        isTrue,
      );
    },
  );
}
