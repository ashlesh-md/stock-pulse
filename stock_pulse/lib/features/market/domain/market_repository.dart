import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

/// Single source of truth for market data: instruments, quotes, candles and
/// the watchlist. Keeps the latest [Quote] per id, so a screen that opens
/// later starts from the cached value instead of a blank row.
abstract interface class MarketRepository {
  /// The default watchlist until a cache seed or an edit.
  static const defaultWatchlist = ['NIFTY', 'RELIANCE', 'HDFCBANK'];

  Quote? latest(String symbol);

  /// Latest known quotes in [ids] order; missing ids are skipped.
  List<Quote> latestQuotes(Iterable<String> ids);

  /// Cached quotes from the last snapshot, shown as stale until the first
  /// live frame. Never overwrites a quote that is already live.
  void seedFromCache(List<Quote> cached);

  List<String> get watchlistIds;

  Stream<List<String>> watchWatchlistIds();

  /// Marks the snapshot dirty (structural change).
  void setWatchlist(List<String> ids);

  /// A 404 (`ServerError`) means the contract is gone.
  Future<Result<Instrument>> getInstrument(String id);

  Future<Result<List<Instrument>>> getInstruments({
    InstrumentKind? kind,
    String? underlying,
  });

  /// Null until [getInstruments] has loaded the list.
  Instrument? instrument(String symbol);

  /// REST snapshot; also updates the cache, so live and snapshot data merge.
  Future<Result<List<Quote>>> getQuotes(
    List<String> symbols, {
    bool full = false,
  });

  /// Everything from [from] (when given) up to now, at most the newest
  /// [limit].
  Future<Result<List<Candle>>> getCandles(
    String symbol,
    CandleInterval interval, {
    DateTime? from,
    int limit = 2000,
  });

  /// Each event is the batch of quotes that changed in one server message.
  /// Subscribes on listen and unsubscribes on cancel.
  Stream<List<Quote>> watchQuotes(
    List<String> symbols,
    FeedMode mode, {
    int throttleMs = 250,
  });
}

abstract interface class CacheSeedableMarket {
  void seedInstruments(List<Instrument> instruments);
}
