import 'package:flutter/material.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.quantity,
    required this.price,
    required this.product,
    this.availableFunds,
    this.marginNotSimulated = false,
  });
  final int quantity;
  final double price;
  final ProductType product;
  final double? availableFunds;
  final bool marginNotSimulated;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.orders;
    final value = price.isFinite ? quantity * price : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    s.estimatedValue,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    Fmt.price(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            if (availableFunds != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      s.fundsAvailable(Fmt.price(availableFunds!)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (marginNotSimulated)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.marginNotSimulated,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (!marginNotSimulated)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(s.margin, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      Fmt.price(value * (product == ProductType.mis ? .2 : 1)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            Text(s.chargesHint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
