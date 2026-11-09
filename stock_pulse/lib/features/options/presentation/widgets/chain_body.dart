import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/core/widgets/sp_multi_picker.dart';
import 'package:stock_pulse/features/options/di/options_providers.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_column.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_header.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_list.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_spot_readout.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_target.dart';
import 'package:stock_pulse/features/options/presentation/widgets/expiry_chips.dart';

/// Spot line, expiry chips, column header and the rows of a loaded chain.
class ChainBody extends ConsumerStatefulWidget {
  const ChainBody({super.key, required this.target, this.pendingExpiry});
  final ChainTarget target;
  final String? pendingExpiry;

  @override
  ConsumerState<ChainBody> createState() => _ChainBodyState();
}

class _ChainBodyState extends ConsumerState<ChainBody> {
  Set<ChainColumn> _columns = {
    ChainColumn.oi,
    ChainColumn.oiChange,
    ChainColumn.ltp,
  };

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final provider = chainControllerProvider(target);
    final (expiries, expiry, strikes) = ref.watch(
      provider.select((a) {
        final value = a.requireValue;
        return (
          value.expiries,
          value.expiry,
          value.view?.strikes ?? const <int>[],
        );
      }),
    );
    final atm = ref.read(provider).requireValue.view?.atm;
    final s = context.strings.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChainSpotReadout(target: target),
        ExpiryChips(
          expiries: expiries,
          selected: widget.pendingExpiry ?? expiry,
          onSelected: (e) => context.goTo(
            OptionChainRoute(underlying: target.underlying, expiry: e.code),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpSpace.gutter,
            vertical: SpSpace.s1,
          ),
          child: SpMultiPicker<ChainColumn>(
            title: s.columns,
            values: ChainColumn.values,
            label: (column) => switch (column) {
              ChainColumn.oi => s.oi,
              ChainColumn.oiChange => s.oiChange,
              ChainColumn.ltp => s.ltp,
              ChainColumn.iv => s.iv,
              ChainColumn.delta => s.delta,
            },
            selected: _columns,
            disabledValues: const [ChainColumn.ltp],
            description: (column) =>
                column == ChainColumn.ltp ? s.alwaysShown : null,
            onChanged: (columns) => setState(() => _columns = columns),
          ),
        ),
        ChainHeader(columns: _columns),
        Expanded(
          child: strikes.isEmpty || atm == null
              ? Center(child: Text(s.empty))
              : ChainList(
                  key: ValueKey((target.underlying, expiry)),
                  target: target,
                  strikes: strikes,
                  atm: atm,
                  columns: _columns,
                ),
        ),
      ],
    );
  }
}
