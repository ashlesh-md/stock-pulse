import 'package:flutter/material.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/more/domain/funds_limits.dart';

/// One-tap amounts; [onPicked] is null while a payment is in flight.
class QuickAmountChips extends StatelessWidget {
  const QuickAmountChips({super.key, required this.onPicked});

  final ValueChanged<double>? onPicked;

  @override
  Widget build(BuildContext context) {
    final onPicked = this.onPicked;
    return Semantics(
      container: true,
      label: context.strings.more.quickAmounts,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final amount in FundsLimits.quickAmounts)
            ActionChip(
              label: Text(Fmt.price(amount)),
              onPressed: onPicked == null ? null : () => onPicked(amount),
            ),
        ],
      ),
    );
  }
}
