import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/orders/application/order_draft.dart';

/// Quantity (or lots) with 48 dp − / + buttons around a number field.
class OrderQuantityField extends StatelessWidget {
  const OrderQuantityField({
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
  final ValueChanged<int?>? onChanged;

  void _step(int by) {
    final current = int.tryParse(controller.text) ?? 0;
    final next = (current + by).clamp(1, OrderDraft.maxCount);
    controller.text = '$next';
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final common = context.strings.common;
    final enabled = onChanged != null;
    return TextField(
      controller: controller,
      enabled: enabled,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (text) => onChanged?.call(int.tryParse(text)),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixIcon: IconButton(
          tooltip: common.decrease(label),
          icon: const Icon(AppIcons.decrease),
          onPressed: enabled ? () => _step(-1) : null,
        ),
        suffixIcon: IconButton(
          tooltip: common.increase(label),
          icon: const Icon(AppIcons.increase),
          onPressed: enabled ? () => _step(1) : null,
        ),
      ),
    );
  }
}
