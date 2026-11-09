import 'package:stock_pulse/core/market_time/domain/freshness.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';

enum TicketBlock {
  unavailable,
  closed,
  preOpen,
  instrument,
  quantity,
  price,
  trigger,
  product,
  expired,
  cutoff,
  risk,
  funds,
}

TicketBlock? validateTicket({
  required Quote? quote,
  required Instrument? instrument,
  required MarketClockState clock,
  required DateTime serverNow,
  required bool socketLive,
  required bool riskAcked,
  required OrderSide side,
  required OrderType type,
  required ProductType product,
  required int quantity,
  int? lots,
  double? limitPrice,
  double? triggerPrice,
  double? availableFunds,
}) {
  if (!socketLive ||
      quote == null ||
      quote.fromCache ||
      serverNow.difference(quote.asOf) > kStaleAfter) {
    return TicketBlock.unavailable;
  }
  if (clock.phase == MarketPhase.closed) return TicketBlock.closed;
  if (instrument == null || instrument.kind == InstrumentKind.marketIndex) {
    return TicketBlock.instrument;
  }
  final option = instrument.kind == InstrumentKind.option;
  if (option && !riskAcked) return TicketBlock.risk;
  if (option &&
      instrument.expiry != null &&
      instrument.expiry!.compareTo(clock.tradingDay) < 0) {
    return TicketBlock.expired;
  }
  if (clock.phase == MarketPhase.preOpen &&
      (option || type != OrderType.limit || product != ProductType.cnc)) {
    return TicketBlock.preOpen;
  }
  if ((option && product == ProductType.cnc) ||
      (!option && product == ProductType.nrml)) {
    return TicketBlock.product;
  }
  final ist = clock
      .marketNow(serverNow)
      .add(const Duration(hours: 5, minutes: 30));
  if (product == ProductType.mis &&
      ist.hour * 60 + ist.minute >= 15 * 60 + 20) {
    return TicketBlock.cutoff;
  }
  if (quantity < 1 ||
      quantity > 10000 ||
      (option &&
          (lots == null ||
              lots < 1 ||
              quantity != lots * instrument.lotSize))) {
    return TicketBlock.quantity;
  }
  bool valid(double? price) =>
      price != null &&
      price.isFinite &&
      price > 0 &&
      (price / instrument.tickSize - (price / instrument.tickSize).round())
              .abs() <
          .000001 &&
      (instrument.bandLow == null || price >= instrument.bandLow!) &&
      (instrument.bandHigh == null || price <= instrument.bandHigh!);
  if (type != OrderType.market && !valid(limitPrice)) return TicketBlock.price;
  if (type == OrderType.sl &&
      (!valid(triggerPrice) ||
          (side == OrderSide.buy
              ? triggerPrice! > limitPrice! || triggerPrice <= quote.ltp
              : triggerPrice! < limitPrice! || triggerPrice >= quote.ltp))) {
    return TicketBlock.trigger;
  }
  final margin =
      quantity *
      (limitPrice ?? quote.ltp) *
      (product == ProductType.mis ? .2 : 1);
  if (availableFunds != null &&
      side == OrderSide.buy &&
      margin > availableFunds) {
    return TicketBlock.funds;
  }
  return null;
}
