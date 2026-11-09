import 'package:flutter/material.dart';
import 'package:option_math/option_math.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/l10n/strings/options_strings.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';

Future<void> showGreeksSheet(
  BuildContext context, {
  required String underlying,
  required int strike,
  required double spot,
  required Expiry expiry,
  required DateTime now,
  required OptionCell? call,
  required OptionCell? put,
}) => showSpSheet<void>(
  context,
  builder: (_) => GreeksSheet(
    underlying: underlying,
    strike: strike,
    spot: spot,
    expiry: expiry,
    now: now,
    call: call,
    put: put,
  ),
);

class GreeksSheet extends StatelessWidget {
  const GreeksSheet({
    super.key,
    required this.underlying,
    required this.strike,
    required this.spot,
    required this.expiry,
    required this.now,
    required this.call,
    required this.put,
  });

  final String underlying;
  final int strike;
  final double spot;
  final Expiry expiry;
  final DateTime now;
  final OptionCell? call;
  final OptionCell? put;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.options;
    final sp = context.sp;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpSpace.s5,
          0,
          SpSpace.s5,
          SpSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.greeks, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: SpSpace.s1),
            Text(
              '$underlying · ${Fmt.integer(strike)} · Spot ${Fmt.price(spot)}',
            ),
            const SizedBox(height: SpSpace.s4),
            for (final (label, cell, right) in [
              (strings.call, call, OptionRight.ce),
              (strings.put, put, OptionRight.pe),
            ]) ...[
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              if (cell?.iv case final iv?)
                _GreeksValues(
                  values: greeks(
                    right: right,
                    spot: spot,
                    strike: strike.toDouble(),
                    years: yearsToExpiry(now, expiry.expiryAt),
                    iv: iv / 100,
                  ),
                  strings: strings,
                  color: sp.textSecondary,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: SpSpace.s1),
                  child: Text(strings.greeksUnavailable),
                ),
              const SizedBox(height: SpSpace.s3),
            ],
          ],
        ),
      ),
    );
  }
}

class _GreeksValues extends StatelessWidget {
  const _GreeksValues({
    required this.values,
    required this.strings,
    required this.color,
  });

  final Greeks values;
  final OptionsStrings strings;
  final Color color;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: SpSpace.s4,
    runSpacing: SpSpace.s1,
    children: [
      _value(strings.delta, values.delta),
      _value(strings.gamma, values.gamma),
      _value(strings.theta, values.theta),
      _value(strings.vega, values.vega),
    ],
  );

  Widget _value(String label, double value) => Text(
    strings.greekValue(label, Fmt.number(value)),
    style: TextStyle(color: color),
  );
}
