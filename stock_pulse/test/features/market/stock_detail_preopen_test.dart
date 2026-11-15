import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

import '../../helpers/fake_analytics_sink.dart';
import '../../helpers/fake_crash_reporter.dart';
import '../../helpers/fake_market_repository.dart';

class _PreOpenMarket extends FakeMarketRepository {
  _PreOpenMarket()
    : super(
        instruments: const [
          Instrument(
            symbol: 'TCS',
            name: 'TCS',
            exchange: 'NSE',
            sector: 'IT',
            tickSize: .05,
            lotSize: 1,
          ),
        ],
        quotes: [
          Quote(
            symbol: 'TCS',
            ltp: 100,
            change: 0,
            changePercent: 0,
            lastTradeTime: DateTime.utc(2026, 11, 11, 10),
            prevClose: 100,
          ),
        ],
      );

  int calls = 0;
  bool failFallback = false;
  final previous = [
    Candle(
      start: DateTime.utc(2026, 11, 11, 4),
      open: 99,
      high: 101,
      low: 98,
      close: 100,
      volume: 500,
    ),
  ];

  @override
  Future<Result<List<Candle>>> getCandles(
    String symbol,
    CandleInterval interval, {
    DateTime? from,
    int limit = 2000,
  }) async {
    calls++;
    if (calls > 1 && failFallback) return const Failure(NetworkError());
    return Success(calls == 1 ? const [] : previous);
  }
}

void main() {
  test(
    'B25 loads the last traded session when 1D has no current candles',
    () async {
      final market = _PreOpenMarket();
      final container = ProviderContainer.test(
        overrides: [
          marketRepositoryProvider.overrideWithValue(market),
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
          analyticsProvider.overrideWithValue(
            AnalyticsService(
              [FakeAnalyticsSink()],
              FakeCrashReporter(),
              consent: () => true,
            ),
          ),
        ],
      );
      container.listen(stockDetailControllerProvider('TCS'), (_, _) {});

      final state = await container.read(
        stockDetailControllerProvider('TCS').future,
      );

      expect(market.calls, 2);
      expect(state.candles, market.previous);
      expect(state.previousSession, isTrue);
    },
  );
  test(
    'B25 failed previous-session fetch leaves a usable empty chart',
    () async {
      final market = _PreOpenMarket()..failFallback = true;
      final container = ProviderContainer.test(
        overrides: [
          marketRepositoryProvider.overrideWithValue(market),
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
          analyticsProvider.overrideWithValue(
            AnalyticsService(
              [FakeAnalyticsSink()],
              FakeCrashReporter(),
              consent: () => true,
            ),
          ),
        ],
      );
      container.listen(stockDetailControllerProvider('TCS'), (_, _) {});

      final state = await container.read(
        stockDetailControllerProvider('TCS').future,
      );

      expect(market.calls, 2);
      expect(state.candles, isEmpty);
      expect(state.previousSession, isFalse);
    },
  );
}
