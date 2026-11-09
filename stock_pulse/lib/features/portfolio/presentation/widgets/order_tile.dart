import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/l10n/strings/portfolio_strings.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';

/// One order; an open order has a Cancel button.
class OrderTile extends StatelessWidget {
  const OrderTile({
    super.key,
    required this.order,
    required this.onCancel,
    this.onRefreshStatus,
    this.waitingForConnection = false,
  });

  final Order order;
  final VoidCallback onCancel;
  final VoidCallback? onRefreshStatus;
  final bool waitingForConnection;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final p = strings.portfolio;
    final buy = order.side == OrderSide.buy;
    final price = switch (order) {
      Order(averagePrice: final v?) => p.atPrice(Fmt.number(v)),
      Order(limitPrice: final v?) => p.limitAt(Fmt.number(v)),
      _ => p.marketPrice,
    };
    return ListTile(
      leading: Text(
        buy ? strings.orders.buy : strings.orders.sell,
        style: TextStyle(
          color: buy ? context.sp.buy : context.sp.sell,
          fontWeight: FontWeight.bold,
        ),
      ),
      title: Text(p.orderTitle(order.symbol, order.quantity, price)),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.orderSubtitle(order.id, switch (order.type) {
              OrderType.market => strings.orders.market,
              OrderType.limit => strings.orders.limit,
              OrderType.sl => strings.orders.stopLoss,
            }, Fmt.time(order.updatedAt)),
          ),
          if (order.status == OrderStatus.pending)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.pending, size: 14, color: context.sp.info),
                const SizedBox(width: 4),
                Text(
                  p.statusPending,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.sp.info),
                ),
              ],
            ),
        ],
      ),
      trailing: order.status == OrderStatus.pending
          ? TextButton(
              onPressed: waitingForConnection ? null : onRefreshStatus,
              child: Text(
                waitingForConnection ? p.waitingForConnection : p.refreshStatus,
              ),
            )
          : order.status == OrderStatus.open ||
                order.status == OrderStatus.queued ||
                order.status == OrderStatus.triggerPending
          ? TextButton(onPressed: onCancel, child: Text(p.cancel))
          : Chip(
              label: Text(_status(p, order.status)),
              visualDensity: VisualDensity.compact,
            ),
    );
  }

  static String _status(PortfolioStrings p, OrderStatus s) => switch (s) {
    OrderStatus.pending => p.statusPending,
    OrderStatus.queued => p.statusQueued,
    OrderStatus.triggerPending => p.statusTriggerPending,
    OrderStatus.open => p.statusOpen,
    OrderStatus.complete => p.statusComplete,
    OrderStatus.cancelled => p.statusCancelled,
    OrderStatus.rejected => p.statusRejected,
  };
}
