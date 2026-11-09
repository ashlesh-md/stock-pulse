import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/ticket_validation.dart';

void main() {
  final now = DateTime.utc(2026, 11, 9, 5);
  final quote = Quote(
    symbol: 'TCS',
    ltp: 100,
    change: 0,
    changePercent: 0,
    lastTradeTime: now,
  );
  const equity = Instrument(
    symbol: 'TCS',
    name: 'TCS',
    exchange: 'NSE',
    sector: '',
    tickSize: .05,
    lotSize: 1,
    bandLow: 80,
    bandHigh: 120,
  );
  const option = Instrument(
    symbol: 'NIFTY:2026-11-10:24000:CE',
    name: 'Call',
    exchange: 'NFO',
    sector: '',
    tickSize: .05,
    lotSize: 65,
    kind: InstrumentKind.option,
    expiry: '2026-11-10',
  );
  final clock = MarketClockState.fallback.copyWith(tradingDay: '2026-11-09');
  TicketBlock? validate({
    Quote? q,
    Instrument? i,
    MarketClockState? c,
    DateTime? time,
    bool live = true,
    bool risk = true,
    OrderSide side = OrderSide.buy,
    OrderType type = OrderType.market,
    ProductType product = ProductType.cnc,
    int quantity = 1,
    int? lots,
    double? price,
    double? trigger,
    double? funds,
  }) => validateTicket(
    quote: q ?? quote,
    instrument: i ?? equity,
    clock: c ?? clock,
    serverNow: time ?? now,
    socketLive: live,
    riskAcked: risk,
    side: side,
    type: type,
    product: product,
    quantity: quantity,
    lots: lots,
    limitPrice: price,
    triggerPrice: trigger,
    availableFunds: funds,
  );
  test('fresh live equity market and delivery pre-open limit orders pass', () {
    expect(validate(), isNull);
    expect(
      validate(
        c: clock.copyWith(phase: MarketPhase.preOpen),
        type: OrderType.limit,
        price: 100,
      ),
      isNull,
    );
  });
  test('stale, cached, missing and offline quotes block submission', () {
    expect(validate(live: false), TicketBlock.unavailable);
    expect(validate(time: now.add(const Duration(milliseconds: 4900))), isNull);
    expect(validate(time: now.add(const Duration(seconds: 5))), isNull);
    expect(
      validate(time: now.add(const Duration(milliseconds: 5100))),
      TicketBlock.unavailable,
    );
    expect(
      validate(q: quote.copyWith(fromCache: true)),
      TicketBlock.unavailable,
    );
    expect(
      validateTicket(
        quote: null,
        instrument: equity,
        clock: clock,
        serverNow: now,
        socketLive: true,
        riskAcked: true,
        side: OrderSide.buy,
        type: OrderType.market,
        product: ProductType.cnc,
        quantity: 1,
      ),
      TicketBlock.unavailable,
    );
  });
  test(
    'closed, invalid pre-open, incompatible product and MIS cutoff block',
    () {
      expect(
        validate(c: clock.copyWith(phase: MarketPhase.closed)),
        TicketBlock.closed,
      );
      expect(
        validate(c: clock.copyWith(phase: MarketPhase.preOpen)),
        TicketBlock.preOpen,
      );
      expect(validate(product: ProductType.nrml), TicketBlock.product);
      final cutoff = DateTime.utc(2026, 11, 9, 10);
      expect(
        validate(
          q: Quote(
            symbol: 'TCS',
            ltp: 100,
            change: 0,
            changePercent: 0,
            lastTradeTime: cutoff,
          ),
          time: cutoff,
          product: ProductType.mis,
        ),
        TicketBlock.cutoff,
      );
    },
  );
  test('options require acknowledgement, valid lots, product and an unexpired contract', () {
    expect(
      validate(
        i: option,
        c: clock.copyWith(phase: MarketPhase.preOpen),
        product: ProductType.nrml,
        quantity: 65,
        lots: 1,
      ),
      TicketBlock.preOpen,
    );
    expect(
      validate(i: option, product: ProductType.nrml, quantity: 65, lots: 1),
      isNull,
    );
    expect(
      validate(
        i: option,
        product: ProductType.nrml,
        quantity: 65,
        lots: 1,
        risk: false,
      ),
      TicketBlock.risk,
    );
    expect(
      validate(
        i: option,
        c: clock.copyWith(tradingDay: '2026-11-11'),
        product: ProductType.nrml,
        quantity: 65,
        lots: 1,
      ),
      TicketBlock.expired,
    );
    expect(validate(i: option, quantity: 65, lots: 1), TicketBlock.product);
    expect(
      validate(i: option, product: ProductType.nrml, quantity: 64, lots: 1),
      TicketBlock.quantity,
    );
    expect(
      validate(i: option, product: ProductType.nrml, quantity: 65),
      TicketBlock.quantity,
    );
  });
  test('quantity, tick, band, non-finite and trigger validation', () {
    expect(validate(quantity: 0), TicketBlock.quantity);
    expect(validate(quantity: 10001), TicketBlock.quantity);
    for (final price in [
      double.nan,
      double.infinity,
      -1.0,
      0.0,
      100.01,
      130.0,
    ]) {
      expect(validate(type: OrderType.limit, price: price), TicketBlock.price);
    }
    expect(validate(type: OrderType.sl, price: 110, trigger: 105), isNull);
    expect(
      validate(type: OrderType.sl, price: 105, trigger: 110),
      TicketBlock.trigger,
    );
    expect(
      validate(type: OrderType.sl, price: 99, trigger: 98),
      TicketBlock.trigger,
    );
    expect(
      validate(
        type: OrderType.sl,
        side: OrderSide.sell,
        price: 90,
        trigger: 95,
      ),
      isNull,
    );
    expect(
      validate(
        type: OrderType.sl,
        side: OrderSide.sell,
        price: 96,
        trigger: 95,
      ),
      TicketBlock.trigger,
    );
    expect(validate(type: OrderType.sl, price: 110), TicketBlock.trigger);
  });
  test('available funds block buys while sells may close a position', () {
    expect(validate(quantity: 2, funds: 150), TicketBlock.funds);
    expect(validate(quantity: 2, funds: 150, side: OrderSide.sell), isNull);
    expect(validate(quantity: 2, funds: 150, product: ProductType.mis), isNull);
  });
}
