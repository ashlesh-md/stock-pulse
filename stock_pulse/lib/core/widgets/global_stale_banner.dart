import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/freshness.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/widgets/stale_badge.dart';

/// Feed-level `Prices not live since hh:mm:ss` banner,
/// mounted in `MaterialApp.builder` above the navigator.
///
/// Shows when no frame arrived for more than 5 s while Open, or the socket
/// has not been live for more than 5 s; it goes on the first live frame.
/// The tree shape never changes, so [child] keeps its state.
class GlobalStaleBanner extends ConsumerWidget {
  const GlobalStaleBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stale = ref.watch(feedStaleProvider);
    return Column(
      children: [
        if (stale.stale)
          Material(
            type: MaterialType.transparency,
            child: SafeArea(
              bottom: false,
              child: StaleBadge.banner(asOf: stale.since),
            ),
          ),
        Expanded(
          key: const ValueKey('app'),
          child: MediaQuery.removePadding(
            context: context,
            removeTop: stale.stale,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Feed staleness for the banner. `since` = last frame (device time), null
/// when no frame ever arrived.
typedef FeedStale = ({bool stale, DateTime? since});

/// Re-evaluated on the 250 ms freshness tick; listeners see only flips.
final feedStaleProvider = Provider.autoDispose<FeedStale>((ref) {
  final clock = ref.watch(clockProvider);
  final startedAt = ref.watch(_bannerStartedAtProvider);
  final socket = ref.watch(marketSocketProvider);
  ref.watch(freshnessTickProvider);
  final live = ref.watch(networkStatusProvider).value == NetworkStatus.live;
  final phase =
      (ref.watch(marketClockProvider).value ?? MarketClockState.fallback).phase;
  final last = socket.lastFrameAt;
  final silentFor = clock.now().difference(last ?? startedAt);
  final stale = (phase == MarketPhase.open || !live) && silentFor > kStaleAfter;
  return (stale: stale, since: stale ? last : null);
});

/// When the banner started watching: the reference while no frame arrived.
final _bannerStartedAtProvider = Provider.autoDispose<DateTime>(
  (ref) => ref.watch(clockProvider).now(),
);
