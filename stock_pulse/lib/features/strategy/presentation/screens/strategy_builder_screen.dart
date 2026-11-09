import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';
import 'package:stock_pulse/features/strategy/presentation/widgets/payoff_chart.dart';
import 'package:stock_pulse/features/strategy/presentation/widgets/strategy_leg_row.dart';

class StrategyBuilderScreen extends ConsumerWidget {
  const StrategyBuilderScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(strategyDraftControllerProvider);
    final state = ref.watch(strategyBuilderControllerProvider);
    final s = context.strings.strategy;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.orders.strategyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            s.legs(draft.shownLegs.length),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (draft.shownLegs.isEmpty) Text(s.empty),
          if (state.hasError)
            TextButton(
              onPressed: () =>
                  ref.read(strategyBuilderControllerProvider.notifier).retry(),
              child: Text(s.failed),
            ),
          if (state.value case final value?) ...[
            if (value.summary case final summary?) ...[
              if (value.geometry case final geometry?)
                PayoffChart(
                  geometry: geometry,
                  summary: s.maxLossValue(
                    summary.maxLoss == null
                        ? s.unlimited
                        : Fmt.price(summary.maxLoss!.abs()),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      s.maxProfitValue(
                        summary.maxProfit == null
                            ? s.unlimited
                            : Fmt.price(summary.maxProfit!),
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      s.maxLossValue(
                        summary.maxLoss == null
                            ? s.unlimited
                            : Fmt.price(summary.maxLoss!.abs()),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                s.breakevensValue(summary.breakevens.map(Fmt.price).toList()),
              ),
              Text(s.netPremiumValue(Fmt.price(summary.netPremium))),
              if (!value.todayLive) Text(s.todayUnavailable),
            ],
          ],
          for (var i = 0; i < draft.shownLegs.length; i++)
            StrategyLegRow(
              key: ValueKey('${draft.shownLegs[i].contractId}.$i'),
              leg: draft.shownLegs[i],
              index: i,
            ),
          TextButton(
            onPressed: () => context.goTo(
              OptionChainRoute(
                underlying: state.value?.instruments.firstOrNull?.underlying,
              ),
            ),
            child: Text(s.openChain),
          ),
          Text(s.preview),
        ],
      ),
    );
  }
}
