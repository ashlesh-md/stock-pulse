import 'dart:async';

import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

/// In-memory [MarketRepository] for widget and controller tests: seed
/// instruments and quotes, then [push] quotes to every matching watcher.
class FakeMarketRepository implements MarketRepository {
  FakeMarketRepository({
    List<Instrument> instruments = const [],
    Iterable<Quote> quotes = const [],
  }) : _instruments = List.of(instruments) {
    for (final q in quotes) {
      _latest[q.id] = q;
    }
  }

  final List<Instrument> _instruments;
  final Map<String, Quote> _latest = {};
  final _updates = StreamController<List<Quote>>.broadcast(sync: true);
  final _watchlist = StreamController<List<String>>.broadcast(sync: true);
  List<String> _watchlistIds = MarketRepository.defaultWatchlist;

  /// Every `watchQuotes` call: ids, mode, throttle.
  final List<({List<String> ids, FeedMode mode, int throttleMs})> watchCalls =
      [];

  /// Number of watchers currently listening.
  int activeWatchers = 0;
  int structuralDirtyCount = 0;

  /// Candles returned by [getCandles], per id.
  final Map<String, List<Candle>> candles = {};

  /// Updates the cache and emits to watchers of these ids.
  void push(List<Quote> quotes) {
    for (final q in quotes) {
      _latest[q.id] = q;
    }
    _updates.add(quotes);
  }

  @override
  Quote? latest(String symbol) => _latest[symbol];

  @override
  List<Quote> latestQuotes(Iterable<String> ids) => [
    for (final id in ids) ?_latest[id],
  ];

  @override
  void seedFromCache(List<Quote> cached) {
    for (final q in cached) {
      _latest.putIfAbsent(q.id, () => q.copyWith(fromCache: true));
    }
  }

  @override
  List<String> get watchlistIds => _watchlistIds;

  @override
  Stream<List<String>> watchWatchlistIds() => _watchlist.stream;

  @override
  void setWatchlist(List<String> ids) {
    _watchlistIds = List.unmodifiable(ids);
    structuralDirtyCount++;
    _watchlist.add(_watchlistIds);
  }

  @override
  Instrument? instrument(String symbol) =>
      _instruments.where((i) => i.id == symbol).firstOrNull;

  @override
  Future<Result<Instrument>> getInstrument(String id) async =>
      switch (instrument(id)) {
        final Instrument i => Success(i),
        null => const Failure(
          ServerError(404, 'unknown_symbol', 'Contract data unavailable'),
        ),
      };

  @override
  Future<Result<List<Instrument>>> getInstruments({
    InstrumentKind? kind,
    String? underlying,
  }) async => Success([
    for (final i in _instruments)
      if ((kind == null || i.kind == kind) &&
          (underlying == null || i.underlying == underlying))
        i,
  ]);

  @override
  Future<Result<List<Quote>>> getQuotes(
    List<String> symbols, {
    bool full = false,
  }) async => Success(latestQuotes(symbols));

  @override
  Future<Result<List<Candle>>> getCandles(
    String symbol,
    CandleInterval interval, {
    DateTime? from,
    int limit = 2000,
  }) async => Success(candles[symbol] ?? const []);

  @override
  Stream<List<Quote>> watchQuotes(
    List<String> symbols,
    FeedMode mode, {
    int throttleMs = 250,
  }) {
    watchCalls.add((ids: symbols, mode: mode, throttleMs: throttleMs));
    final wanted = symbols.toSet();
    StreamSubscription<List<Quote>>? inner;
    // Single-subscription: cancelling its one listener releases it.
    // ignore: close_sinks
    late final StreamController<List<Quote>> c;
    c = StreamController<List<Quote>>(
      onListen: () {
        activeWatchers++;
        final cached = latestQuotes(wanted);
        if (cached.isNotEmpty) c.add(cached);
        inner = _updates.stream
            .map(
              (b) => [
                for (final q in b)
                  if (wanted.contains(q.id)) q,
              ],
            )
            .where((b) => b.isNotEmpty)
            .listen(c.add);
      },
      onCancel: () async {
        activeWatchers--;
        await inner?.cancel();
      },
    );
    return c.stream;
  }
}
