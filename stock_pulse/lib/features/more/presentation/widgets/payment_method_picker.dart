import 'package:flutter/material.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/more/domain/payment_method.dart';

/// UPI or net banking; disabled while a payment is in flight.
class PaymentMethodPicker extends StatelessWidget {
  const PaymentMethodPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final PaymentMethod selected;
  final ValueChanged<PaymentMethod>? onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.more;
    final onChanged = this.onChanged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.paymentMethod, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<PaymentMethod>(
          segments: [
            ButtonSegment(value: PaymentMethod.upi, label: Text(s.upi)),
            ButtonSegment(
              value: PaymentMethod.netBanking,
              label: Text(s.netBanking),
            ),
          ],
          selected: {selected},
          onSelectionChanged: onChanged == null
              ? null
              : (value) => onChanged(value.single),
        ),
      ],
    );
  }
}
