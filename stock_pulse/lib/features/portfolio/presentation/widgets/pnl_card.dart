import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_funds_provider.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_summary.dart';

/// `+₹12.35`, `−₹4.10`, or a neutral `₹0.00` when the total rounds to zero.
String pnlText(double value) {
  final paise = (value * 100).round();
  final money = Fmt.price(paise.abs() / 100);
  return switch (paise.sign) {
    1 => '+$money',
    -1 => '−$money',
    _ => money,
  };
}

/// Unrealised (live) and realised P&L side by side; rebuilds only when a
/// total changes.
class PnlCard extends ConsumerWidget {
  const PnlCard({super.key, required this.section});

  final PortfolioSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (summary, unrealised, realised) = ref.watch(
      portfolioControllerProvider.select((a) {
        final state = a.value;
        return (
          state?.summary ?? PortfolioSummary.empty,
          state?.unrealizedPnl ?? 0.0,
          state?.realizedPnl ?? 0.0,
        );
      }),
    );
    final funds = ref.watch(portfolioFundsProvider).value?.available;
    final strings = context.strings.portfolio;
    final values = section == PortfolioSection.holdings
        ? <(String, double)>[
            (strings.invested, summary.invested),
            (strings.currentValue, summary.current),
            (strings.dayPnl, summary.dayPnl),
            (strings.totalPnl, summary.totalPnl),
          ]
        : <(String, double)>[
            (strings.unrealisedLive, unrealised),
            (strings.realised, realised),
          ];
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < values.length; i += 2)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: Row(
                  children: [
                    for (final (label, value) in values.skip(i).take(2))
                      Expanded(child: _cell(context, label, value)),
                  ],
                ),
              ),
            if (funds != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(strings.fundsAvailable(Fmt.price(funds))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, String label, double value) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        Text(
          pnlText(value),
          style: theme.textTheme.titleLarge?.copyWith(
            color: context.sp.directionOf((value * 100).round()),
          ),
        ),
      ],
    );
  }
}
