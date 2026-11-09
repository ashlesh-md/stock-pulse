import 'dart:math';

import 'package:market_server/src/account_book.dart';
import 'package:market_server/src/broker.dart';
import 'package:market_server/src/clock_scheduler.dart';
import 'package:market_server/src/market_engine.dart';
import 'package:market_server/src/models.dart';

class ExpiryService {
  ExpiryService(this.engine, this.broker, this.account);
  final MarketEngine engine;
  final Broker broker;
  final AccountBook account;
  final _settled = <String>{};

  void squareOff(BoundaryEvent event) {
    for (final order in broker.orders) {
      if (order.product == ProductType.mis && _pending(order)) {
        broker.cancel(order.id);
      }
    }
    for (final position in broker.positions) {
      if (position.product != ProductType.mis || position.quantity == 0) {
        continue;
      }
      broker.closePosition(
        position,
        engine[position.symbol]!.ltp,
        reason: 'auto_square_off',
      );
    }
  }

  void settle(BoundaryEvent event) {
    for (final order in broker.orders) {
      if (engine[order.symbol]?.instrument.expiry == '${event.tradingDay}' &&
          _pending(order)) {
        broker.cancel(order.id);
      }
    }
    for (final position in broker.positions) {
      final instrument = engine[position.symbol]!.instrument;
      if (instrument.expiry != '${event.tradingDay}' ||
          position.quantity == 0) {
        continue;
      }
      final id =
          '${position.symbol}@${event.tradingDay}|${position.product.name}';
      if (!_settled.add(id)) continue;
      final spot = engine[instrument.underlying!]!.ltp;
      final strike = instrument.strike!;
      final price = max(
        0.0,
        instrument.right!.name == 'ce' ? spot - strike : strike - spot,
      );
      final quantity = position.quantity;
      final pnl = (price - position.averagePrice) * quantity;
      broker.closePosition(position, price, reason: 'expired');
      account.settlement({
        'settlementId': id,
        'symbol': position.symbol,
        'product': position.product.name,
        'quantity': quantity,
        'settlePrice': price,
        'pnl': pnl,
        'settledAt': event.at.toIso8601String(),
      });
    }
  }

  bool _pending(Order order) => {
    OrderStatus.open,
    OrderStatus.queued,
    OrderStatus.triggerPending,
  }.contains(order.status);
}
