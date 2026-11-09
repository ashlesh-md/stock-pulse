import 'package:flutter/material.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_column.dart';
import 'package:stock_pulse/features/options/presentation/widgets/oi_bar.dart';

/// One side of a chain row: OI with its bar, ΔOI and LTP, with LTP next to
/// the strike. [call] mirrors the order so both LTPs face the strike.
class OptionSideCell extends StatelessWidget {
  const OptionSideCell({
    super.key,
    required this.cell,
    required this.call,
    required this.strike,
    required this.itm,
    this.maxOi = 0,
    this.oiFraction,
    required this.columns,
    required this.onTap,
  });

  final OptionCell? cell;
  final bool call;
  final int strike;
  final bool itm;
  final int maxOi;
  final double? oiFraction;
  final Set<ChainColumn> columns;
  final ValueChanged<OptionCell> onTap;

  @override
  Widget build(BuildContext context) {
    final sp = context.sp;
    final cell = this.cell;
    final s = context.strings.options;
    if (cell == null) {
      return Center(child: Text(context.strings.common.noValue));
    }
    final style = context.spText.change.copyWith(color: sp.textPrimary);
    Widget value(ChainColumn column) => switch (column) {
      ChainColumn.oi => _oi(
        cell,
        sp,
        call,
        oiFraction ?? (maxOi == 0 ? 0 : cell.oi / maxOi),
        style,
      ),
      ChainColumn.oiChange => _fit(
        Text(
          _signedCompact(cell.oiChange),
          style: style.copyWith(color: sp.directionOf(cell.oiChange)),
          textAlign: TextAlign.center,
        ),
      ),
      ChainColumn.ltp => _fit(
        Text(
          Fmt.number(cell.ltp),
          style: style.copyWith(fontWeight: FontWeight.w600),
          textAlign: call ? TextAlign.end : TextAlign.start,
        ),
      ),
      ChainColumn.iv => _fit(
        Text(
          cell.iv == null
              ? context.strings.common.noValue
              : Fmt.number(cell.iv!),
          style: style,
          textAlign: TextAlign.center,
        ),
      ),
      ChainColumn.delta => _fit(
        Text(
          cell.delta == null
              ? context.strings.common.noValue
              : Fmt.number(cell.delta!),
          style: style,
          textAlign: TextAlign.center,
        ),
      ),
    };
    final children = [
      for (final column in chainSideColumns(columns, call: call))
        Expanded(child: value(column)),
    ];
    return Semantics(
      button: true,
      label: s.cellSemantics(
        call ? s.call : s.put,
        strike,
        Fmt.number(cell.ltp),
        Fmt.compact(cell.oi),
      ),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => onTap(cell),
          child: Container(
            color: itm ? sp.surface1 : null,
            padding: const EdgeInsets.symmetric(horizontal: SpSpace.s2),
            child: Row(children: children),
          ),
        ),
      ),
    );
  }
}

Widget _fit(Widget child) => FittedBox(fit: BoxFit.scaleDown, child: child);

Widget _oi(
  OptionCell cell,
  SpColors sp,
  bool call,
  double fraction,
  TextStyle style,
) => _fit(
  Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: call
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end,
    children: [
      Text(Fmt.compact(cell.oi), style: style),
      const SizedBox(height: 2),
      SizedBox(
        width: 40,
        child: OiBar(
          fraction: fraction,
          color: call ? sp.down : sp.up,
          fromRight: !call,
        ),
      ),
    ],
  ),
);

String _signedCompact(int v) =>
    v == 0 ? '0' : '${v > 0 ? '+' : '−'}${Fmt.compact(v.abs())}';
