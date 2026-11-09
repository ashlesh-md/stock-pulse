import 'package:flutter/material.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_column.dart';

/// Sticky column labels: CALLS (OI ΔOI LTP) | STRIKE | PUTS (LTP ΔOI OI).
class ChainHeader extends StatelessWidget {
  const ChainHeader({super.key, required this.columns});

  final Set<ChainColumn> columns;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.options;
    final sp = context.sp;
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: sp.textSecondary);
    String label(ChainColumn column) => switch (column) {
      ChainColumn.oi => s.oi,
      ChainColumn.oiChange => s.oiChange,
      ChainColumn.ltp => s.ltp,
      ChainColumn.iv => s.iv,
      ChainColumn.delta => s.delta,
    };
    Widget side(String title, {required bool call}) => Expanded(
      flex: 36,
      child: Column(
        children: [
          Text(title, style: style?.copyWith(fontWeight: FontWeight.w700)),
          Row(
            children: [
              for (final column in chainSideColumns(columns, call: call))
                Expanded(
                  child: Text(
                    label(column),
                    style: style,
                    textAlign: _align(column, call: call),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpSpace.s2,
        vertical: SpSpace.s1,
      ),
      decoration: BoxDecoration(
        color: sp.surface1,
        border: Border(bottom: BorderSide(color: sp.outline)),
      ),
      child: Row(
        children: [
          side(s.calls, call: true),
          Expanded(
            flex: 28,
            child: Text(
              s.strikeHeader,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
          side(s.puts, call: false),
        ],
      ),
    );
  }
}

TextAlign _align(ChainColumn column, {required bool call}) => switch (column) {
  ChainColumn.oi => call ? TextAlign.start : TextAlign.end,
  ChainColumn.ltp => call ? TextAlign.end : TextAlign.start,
  ChainColumn.oiChange ||
  ChainColumn.iv ||
  ChainColumn.delta => TextAlign.center,
};
