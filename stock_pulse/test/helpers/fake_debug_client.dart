import 'dart:async';

import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/domain/debug_client.dart';

/// Records clock jumps and resets; set [result] to fail them.
class FakeDebugClient implements DebugClient {
  final clocks = <DateTime>[];
  final resets = <DateTime?>[];
  Result<void> result = const Success(null);

  /// When set, every call waits for it.
  Completer<void>? gate;

  @override
  Future<Result<MarketClockState>> setClock(DateTime marketTime) async {
    clocks.add(marketTime);
    await gate?.future;
    return switch (result) {
      Success() => const Success(
        MarketClockState(
          phase: MarketPhase.open,
          marketOffsetMs: 0,
          mode: 'override',
          tradingDay: '2026-11-10',
        ),
      ),
      Failure(:final error) => Failure(error),
    };
  }

  @override
  Future<Result<void>> reset({DateTime? marketTime}) async {
    resets.add(marketTime);
    await gate?.future;
    return result;
  }
}
