import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/options/di/options_providers.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_target.dart';

/// The spot readout updates independently from the scrollable strike rows.
class ChainSpotReadout extends ConsumerWidget {
  const ChainSpotReadout({super.key, required this.target});

  final ChainTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spot = ref.watch(
      chainControllerProvider(target)
          .select((state) => state.value?.view?.spot),
    );
    if (spot == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpSpace.gutter,
        0,
        SpSpace.gutter,
        SpSpace.s1,
      ),
      child: Text(
        context.strings.options.spot(target.underlying, Fmt.number(spot)),
        style: context.spText.price.copyWith(color: context.sp.textPrimary),
      ),
    );
  }
}
