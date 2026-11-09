import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/options/di/options_providers.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_cell_sheet.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_column.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_target.dart';
import 'package:stock_pulse/features/options/presentation/widgets/greeks_sheet.dart';
import 'package:stock_pulse/features/options/presentation/widgets/option_side_cell.dart';

/// A stable strike row whose call, strike and put subscribe to separate data.
class ChainRowTile extends StatelessWidget {
  const ChainRowTile({
    super.key,
    required this.target,
    required this.strike,
    this.columns = const {
      ChainColumn.oi,
      ChainColumn.oiChange,
      ChainColumn.ltp,
    },
  });

  final ChainTarget target;
  final int strike;
  final Set<ChainColumn> columns;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: SpDensity.chainRow,
    child: Row(
      children: [
        Expanded(
          flex: 36,
          child: _LiveOptionSideCell(
            target: target,
            strike: strike,
            call: true,
            columns: columns,
          ),
        ),
        Expanded(
          flex: 28,
          child: _StrikeCell(
            key: ValueKey('strike:$strike'),
            target: target,
            strike: strike,
          ),
        ),
        Expanded(
          flex: 36,
          child: _LiveOptionSideCell(
            target: target,
            strike: strike,
            call: false,
            columns: columns,
          ),
        ),
      ],
    ),
  );
}

class _LiveOptionSideCell extends ConsumerWidget {
  const _LiveOptionSideCell({
    required this.target,
    required this.strike,
    required this.call,
    required this.columns,
  });

  final ChainTarget target;
  final int strike;
  final bool call;
  final Set<ChainColumn> columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (cell, itm, oiFraction) = ref.watch(
      chainControllerProvider(target).select((asyncState) {
        final view = asyncState.value?.view;
        final row = view?.rows[strike];
        final cell = call ? row?.ce : row?.pe;
        final spot = view?.spot ?? strike.toDouble();
        final maxOi = _maxOi(view);
        final oiBucket = maxOi == 0
            ? 0
            : ((cell?.oi ?? 0) / maxOi * 40).round();
        return (cell, call ? strike < spot : strike > spot, oiBucket / 40);
      }),
    );
    return OptionSideCell(
      cell: cell,
      call: call,
      strike: strike,
      itm: itm,
      oiFraction: oiFraction,
      columns: columns,
      onTap: (selected) => showChainCellSheet(context, selected),
    );
  }
}

class _StrikeCell extends ConsumerWidget {
  const _StrikeCell({super.key, required this.target, required this.strike});

  final ChainTarget target;
  final int strike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atm = ref.watch(
      chainControllerProvider(target)
          .select((asyncState) => asyncState.value?.view?.atm == strike),
    );
    final sp = context.sp;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: atm ? sp.surface2 : null,
        border: Border(
          top: atm ? BorderSide(color: sp.accent, width: 2) : BorderSide.none,
          bottom: BorderSide(color: atm ? sp.accent : sp.outline),
        ),
      ),
      child: InkWell(
        onLongPress: () async {
          final state = ref.read(chainControllerProvider(target)).value;
          final view = state?.view;
          final expiry = state?.expiries
              .where((item) => item.code == state.expiry)
              .firstOrNull;
          if (view == null || expiry == null || !context.mounted) return;
          await showGreeksSheet(
            context,
            underlying: target.underlying,
            strike: strike,
            spot: view.spot,
            expiry: expiry,
            now: ref.read(clockProvider).now(),
            call: view.rows[strike]?.ce,
            put: view.rows[strike]?.pe,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              Fmt.integer(strike),
              style: context.spText.price.copyWith(
                color: sp.textPrimary,
                fontWeight: atm ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (atm)
              Text(
                context.strings.options.atm,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: sp.accent),
              ),
          ],
        ),
      ),
    );
  }
}

int _maxOi(ChainView? view) {
  var max = 0;
  for (final row in view?.rows.values ?? const <ChainRow>[]) {
    final ce = row.ce?.oi ?? 0;
    final pe = row.pe?.oi ?? 0;
    if (ce > max) max = ce;
    if (pe > max) max = pe;
  }
  return max;
}
