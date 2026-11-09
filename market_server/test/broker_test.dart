import 'package:market_server/market_server.dart';
import 'package:market_server/src/account_book.dart';
import 'package:test/test.dart';

import 'support/engine_fixture.dart';

void main() {
  group('Position', () {
    test('averages buys, books profit on a sell, flips to short', () {
      final p = Position('X')
        ..apply(OrderSide.buy, 10, 100)
        ..apply(OrderSide.buy, 10, 110);
      expect(p.quantity, 20);
      expect(p.averagePrice, 105);

      p.apply(OrderSide.sell, 5, 120);
      expect(p.quantity, 15);
      expect(p.realizedPnl, 75); // (120 - 105) * 5
      expect(p.averagePrice, 105);

      p.apply(OrderSide.sell, 20, 100);
      expect(p.quantity, -5); // closed 15 long, opened 5 short
      expect(p.realizedPnl, 0); // 75 + (100 - 105) * 15
      expect(p.averagePrice, 100);
    });
  });

  group('Broker', () {
    late MarketEngine engine;
    late Broker broker;
    setUp(() {
      engine = seededEngine();
      broker = Broker(engine);
    });

    test('market buy fills at the best ask and creates a position', () {
      final ask = engine['ITC']!.bestAsk;
      final order = broker.place(
        symbol: 'ITC',
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 3,
      );
      expect(order.status, OrderStatus.complete);
      expect(order.averagePrice, ask);
      expect(broker.positions.single.quantity, 3);
    });

    test(
      'CNC buys settle on the next day and only settled shares can sell',
      () {
        var now = DateTime.utc(2026, 11, 4, 9, 30);
        final deliveryEngine = seededEngine(clock: () => now);
        final deliveryBroker = Broker(deliveryEngine, clock: () => now);
        final account = AccountBook(deliveryEngine, clock: () => now);
        deliveryBroker.updates.listen(account.recordFill);
        deliveryBroker.availableFunds = () =>
            (account.funds['available']! as num).toDouble();
        addTearDown(deliveryBroker.dispose);
        addTearDown(account.close);
        addTearDown(deliveryEngine.stop);

        final ask = deliveryEngine['ITC']!.bestAsk;
        final buy = deliveryBroker.place(
          symbol: 'ITC',
          side: OrderSide.buy,
          type: OrderType.market,
          quantity: 2,
          product: ProductType.cnc,
        );
        expect(account.funds['available'], 1000000 - 2 * ask);
        expect(deliveryBroker.holdings, isEmpty);
        expect(
          () => deliveryBroker.place(
            symbol: 'ITC',
            side: OrderSide.sell,
            type: OrderType.market,
            quantity: 1,
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

        now = Ist.at(const IstDate(2026, 11, 5), 9, 0);
        final roll = BoundaryEvent(
          BoundaryKind.dayRoll,
          const IstDate(2026, 11, 5),
          now,
        );
        deliveryBroker.settleDelivery(roll);
        deliveryBroker.settleDelivery(roll);
        expect(deliveryBroker.holdings.single.quantity, 2);
        expect(deliveryBroker.positions, isEmpty);

        final proceedsBefore = account.funds['available']! as double;
        final sell = deliveryBroker.place(
          symbol: 'ITC',
          side: OrderSide.sell,
          type: OrderType.market,
          quantity: 1,
          product: ProductType.cnc,
        );
        expect(account.funds['available'], proceedsBefore + sell.averagePrice!);
        expect(deliveryBroker.holdings.single.quantity, 1);
        expect(buy.status, OrderStatus.complete);
      },
    );

    test('limit buy waits, then fills when the ask reaches the limit', () {
      final stock = engine['ITC']!;
      final order = broker.place(
        symbol: 'ITC',
        side: OrderSide.buy,
        type: OrderType.limit,
        quantity: 1,
        limitPrice: stock.bestAsk - 2,
      );
      expect(order.status, OrderStatus.open);
      // Push the price down until the order fills.
      while (order.status == OrderStatus.open) {
        engine.step();
        stock.ltp = stock.ltp - 0.05;
      }
      expect(order.averagePrice, lessThanOrEqualTo(order.limitPrice!));
    });

    test('the same idempotency key never places a second order', () {
      Order place() => broker.place(
        symbol: 'TCS',
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 1,
        idempotencyKey: 'abc',
      );
      final first = place();
      final replay = place();
      expect(replay.id, first.id);
      expect(replay.version, first.version);
      expect(broker.orders, hasLength(1));

      final next = broker.place(
        symbol: 'TCS',
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 1,
      );
      expect(next.version, greaterThan(first.version));
    });

    test('rejects 120.05 outside an 80–120 band and off-grid 101.03', () async {
      final bounded = MarketEngine([
        const Instrument(
          symbol: 'TEST',
          name: 'Test',
          exchange: 'NSE',
          sector: 'Test',
          basePrice: 100,
        ),
      ]);
      bounded['TEST']!.daily[bounded['TEST']!.daily.length - 2].close = 100;
      final boundedBroker = Broker(bounded);
      addTearDown(boundedBroker.dispose);
      addTearDown(bounded.stop);

      expect(
        () => boundedBroker.place(
          symbol: 'TEST',
          side: OrderSide.buy,
          type: OrderType.limit,
          quantity: 1,
          limitPrice: 120.05,
        ),
        throwsA(
          isA<OrderRejection>().having(
            (error) => error.code,
            'code',
            'price_out_of_band',
          ),
        ),
      );
      expect(
        () => boundedBroker.place(
          symbol: 'TEST',
          side: OrderSide.buy,
          type: OrderType.limit,
          quantity: 1,
          limitPrice: 101.03,
        ),
        throwsA(
          isA<OrderRejection>().having(
            (error) => error.code,
            'code',
            'invalid_tick',
          ),
        ),
      );
    });

    test(
      'rejects bad quantity, unknown symbol and prices outside the band',
      () {
        expect(
          () => broker.place(
            symbol: 'TCS',
            side: OrderSide.buy,
            type: OrderType.market,
            quantity: 0,
          ),
          throwsA(
            isA<OrderRejection>().having(
              (e) => e.code,
              'code',
              'invalid_quantity',
            ),
          ),
        );
        expect(
          () => broker.place(
            symbol: 'NOPE',
            side: OrderSide.buy,
            type: OrderType.market,
            quantity: 1,
          ),
          throwsA(isA<OrderRejection>().having((e) => e.status, 'status', 404)),
        );
        expect(
          () => broker.place(
            symbol: 'TCS',
            side: OrderSide.buy,
            type: OrderType.limit,
            quantity: 1,
            limitPrice: 1,
          ),
          throwsA(
            isA<OrderRejection>().having(
              (e) => e.code,
              'code',
              'price_out_of_band',
            ),
          ),
        );
      },
    );

    test('cancel only works on open orders', () {
      final open = broker.place(
        symbol: 'TCS',
        side: OrderSide.sell,
        type: OrderType.limit,
        quantity: 1,
        limitPrice: (engine['TCS']!.prevClose * 1.19 * 20).round() / 20,
      );
      expect(broker.cancel(open.id).status, OrderStatus.cancelled);
      expect(
        () => broker.cancel(open.id),
        throwsA(isA<OrderRejection>().having((e) => e.status, 'status', 409)),
      );
    });
  });
}
