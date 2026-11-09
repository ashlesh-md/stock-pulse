import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/market_time/data/clock_repository.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/market_time/domain/server_clock.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';

/// Device clock; tests override with [FakeClock].
final clockProvider = Provider<Clock>((ref) => const SystemClock());

final serverClockProvider = Provider<ServerClock>(
  (ref) => ServerClock(ref.watch(clockProvider)),
);

final clockRepositoryProvider = Provider<ClockRepository>(
  (ref) => ClockRepository(
    ref.watch(apiClientProvider),
    ref.watch(marketSocketProvider),
  ),
);

final marketClockProvider = StreamProvider<MarketClockState>(
  (ref) => ref.watch(clockRepositoryProvider).watch(),
);

/// Server time every 250 ms, for freshness. autoDispose: it ticks only
/// while a widget shows freshness.
final freshnessTickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = ref.watch(serverClockProvider);
  return Stream<DateTime>.periodic(
    const Duration(milliseconds: 250),
    (_) => clock.now(),
  );
});
