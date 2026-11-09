import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/strings/order_strings.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';

/// One line on an order's state, for snackbars:
/// `BUY 10 TCS filled @ ₹3,066.25`.
String orderSummary(Order o, OrderStrings s) {
  final side = switch (o.side) {
    OrderSide.buy => s.buy,
    OrderSide.sell => s.sell,
  };
  final what = s.what(side, o.quantity, o.symbol);
  return switch (o.status) {
    OrderStatus.pending => s.statusPending,
    OrderStatus.complete => s.filled(what, Fmt.price(o.averagePrice ?? 0)),
    OrderStatus.queued ||
    OrderStatus.triggerPending ||
    OrderStatus.open => s.waiting(what, Fmt.price(o.limitPrice ?? 0)),
    OrderStatus.cancelled => s.cancelled(what),
    OrderStatus.rejected => switch (o.message) {
      null => s.rejected(what),
      final reason => s.rejectedBecause(what, reason),
    },
  };
}
