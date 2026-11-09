import 'package:flutter/material.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// `▲ +12.40 (+0.51%)`. Direction is shown by the glyph and sign,
/// never by colour alone. [compact] (rows) is text only; otherwise it sits
/// on an `upTint`/`downTint` pill (stock page).
class ChangeChip extends StatelessWidget {
  const ChangeChip({
    super.key,
    required this.change,
    required this.changePct,
    this.compact = true,
  });

  final double? change;
  final double? changePct;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sp = context.sp;
    final strings = context.strings.common;
    final c = change, p = changePct;
    final style = context.spText.change;
    if (c == null || p == null) {
      return Semantics(
        label: strings.changeUnavailable,
        child: ExcludeSemantics(
          child: Text(
            strings.noValue,
            style: style.copyWith(color: sp.textSecondary),
          ),
        ),
      );
    }
    final rounded = (c * 100).roundToDouble() / 100;
    final flat = rounded == 0;
    final color = sp.directionOf(rounded);
    final text = flat
        ? '– 0.00 (0.00%)'
        : '${rounded > 0 ? '▲' : '▼'} ${Fmt.signed(c)} (${Fmt.percent(p)})';
    final amount = Fmt.number(c.abs());
    final percent = p.abs().toStringAsFixed(2);
    final label = flat
        ? strings.unchanged
        : rounded > 0
        ? strings.changeUp(amount, percent)
        : strings.changeDown(amount, percent);
    Widget body = Text(text, maxLines: 1, style: style.copyWith(color: color));
    if (!compact && !flat) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          color: rounded > 0 ? sp.upTint : sp.downTint,
          borderRadius: BorderRadius.circular(SpRadius.s),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpSpace.s2,
            vertical: SpSpace.s1,
          ),
          child: body,
        ),
      );
    }
    return Semantics(
      label: label,
      child: ExcludeSemantics(child: body),
    );
  }
}
