import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';

/// A rupee price input; reports null while the text is not a number.
class OrderPriceField extends StatelessWidget {
  const OrderPriceField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;

  /// Null locks the field while the order is being placed.
  final ValueChanged<double?>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enabled: onChanged != null,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    onChanged: (text) => onChanged?.call(double.tryParse(text)),
    decoration: InputDecoration(
      labelText: label,
      errorText: errorText,
      prefixText: context.strings.orders.rupeePrefix,
    ),
  );
}
