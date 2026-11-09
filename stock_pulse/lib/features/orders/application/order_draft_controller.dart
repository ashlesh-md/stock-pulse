import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/orders/application/order_draft.dart';
import 'package:stock_pulse/features/orders/di/order_ticket_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart'
    show OrderSide, OrderType, ProductType;

/// One open order sheet. It lives as long as the sheet; the submission key
/// lives longer, in `OrderTicketController`, so a retry after a dismissed
/// uncertain send reuses it.
class OrderDraftController extends Notifier<OrderDraft> {
  OrderDraftController(this.seed);
  final OrderDraftSeed seed;

  @override
  OrderDraft build() => OrderDraft.fromSeed(seed);

  void setSide(OrderSide side) => _edit(state.copyWith(side: side));
  void setType(OrderType type) => _edit(state.copyWith(type: type));
  void setProduct(ProductType product) =>
      _edit(state.copyWith(product: product));
  void setCount(int? count) => _edit(state.copyWith(count: () => count));
  void setLimitPrice(double? price) =>
      _edit(state.copyWith(limitPrice: () => price));
  void setTriggerPrice(double? price) =>
      _edit(state.copyWith(triggerPrice: () => price));

  /// Sends the draft; true when the order was placed and the sheet can close.
  Future<bool> place() async {
    final draft = state;
    if (draft.submitting || draft.issues.isNotEmpty) return false;
    state = draft.copyWith(submitting: true, error: () => null);
    final error = await ref
        .read(orderTicketControllerProvider(seed.args.instrumentId).notifier)
        .submit(
          side: draft.side,
          type: draft.type,
          quantity: draft.quantity,
          lots: draft.lots,
          product: draft.product,
          limitPrice: draft.sentLimit,
          triggerPrice: draft.sentTrigger,
        );
    if (!ref.mounted) return error == null;
    state = state.copyWith(submitting: false, error: () => error);
    return error == null;
  }

  void _edit(OrderDraft next) {
    if (state.submitting) return;
    state = next.copyWith(error: () => null);
  }
}
