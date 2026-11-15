import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/freshness.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/widgets/stale_badge.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';

class ChartStaleBadge extends ConsumerWidget {
  const ChartStaleBadge({super.key, required this.instrumentId});
  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(
      stockDetailControllerProvider(instrumentId)
          .select((state) => state.value?.quote),
    );
    if (quote == null) return const SizedBox.shrink();
    final status = ref.watch(networkStatusProvider).value;
    final clock = ref.watch(marketClockProvider).value;
    final stale =
        status != NetworkStatus.live ||
        freshnessOf(
              asOf: quote.asOf,
              fromCache: quote.fromCache,
              serverNow: ref.watch(serverClockProvider).now(),
              socketLive: status == NetworkStatus.live,
              phase: clock?.phase ?? MarketPhase.open,
            ) ==
            Freshness.stale;
    return stale ? StaleBadge(asOf: quote.asOf) : const SizedBox.shrink();
  }
}
