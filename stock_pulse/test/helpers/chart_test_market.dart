import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

import 'fake_market_repository.dart';

class CountingMarket extends FakeMarketRepository {
  CountingMarket()
    : super(
        instruments: const [
          Instrument(
            symbol: 'TCS',
            name: 'TCS',
            exchange: 'NSE',
            sector: 'IT',
            tickSize: 0.05,
            lotSize: 1,
          ),
        ],
        quotes: [
          Quote(
            symbol: 'TCS',
            ltp: 100,
            change: 0,
            changePercent: 0,
            lastTradeTime: DateTime.utc(2026, 11, 12),
          ),
        ],
      );
  int loads = 0;
  @override
  Future<Result<List<Candle>>> getCandles(
    String symbol,
    CandleInterval interval, {
    DateTime? from,
    int limit = 2000,
  }) {
    loads++;
    return super.getCandles(symbol, interval, from: from, limit: limit);
  }
}
