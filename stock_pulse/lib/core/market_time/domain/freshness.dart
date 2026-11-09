import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';

/// What a price may claim.
enum Freshness { live, stale, closed }

/// Age above this is stale; exactly 5.000 s is still live.
const kStaleAfter = Duration(seconds: 5);

/// Pure and synchronous; first match wins.
Freshness freshnessOf({
  required DateTime? asOf,
  required bool fromCache,
  required DateTime serverNow,
  required bool socketLive,
  required MarketPhase phase,
}) {
  if (!socketLive || fromCache) return Freshness.stale;
  if (phase != MarketPhase.open) return Freshness.closed;
  if (asOf == null) return Freshness.stale;
  if (serverNow.difference(asOf) > kStaleAfter) return Freshness.stale;
  return Freshness.live;
}
