import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';

/// Debug hooks for More › Reset and the debug clock screen.
abstract interface class DebugClient {
  /// Fails with `ServerError` code `backward_jump_requires_reset` (409) when
  /// [marketTime] is in the past.
  Future<Result<MarketClockState>> setClock(DateTime marketTime);

  /// Resets the market and the account; optional new market time.
  Future<Result<void>> reset({DateTime? marketTime});
}
