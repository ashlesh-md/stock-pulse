import 'package:flutter/material.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/sp_picker.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';

class OrderProductPicker extends StatelessWidget {
  const OrderProductPicker({
    super.key,
    required this.value,
    required this.lotSize,
    required this.onChanged,
  });
  final ProductType value;
  final int lotSize;
  final ValueChanged<ProductType>? onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.orders;
    String label(ProductType product) => switch (product) {
      ProductType.cnc => s.delivery,
      ProductType.mis => s.intraday,
      ProductType.nrml => s.carryForward,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(s.product),
      trailing: SpPicker<ProductType>(
        title: s.product,
        values: [
          if (lotSize == 1) ProductType.cnc,
          ProductType.mis,
          if (lotSize > 1) ProductType.nrml,
        ],
        label: label,
        selected: value,
        enabled: onChanged != null,
        onChanged: (next) => onChanged?.call(next),
      ),
    );
  }
}
