import 'dart:async';

import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/core/storage/domain/snapshot_store.dart';
import 'package:stock_pulse/features/market/data/market_api.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

class LiveMarketRepository implements MarketRepository, CacheSeedableMarket {
  LiveMarketRepository(this._api, this._socket, {this._snapshots}) {
    _subscriptions.add(_socket.messages.listen(_onMessage));
    _removeResyncReloader = _socket.registerResyncReloader(_resync);
  }

  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _disposed = false;
  final ApiClient _api;
  final MarketSocket _socket;
  final SnapshotStore? _snapshots;
  late final void Function() _removeResyncReloader;

  List<String> _watchlistIds = List.unmodifiable(
    MarketRepository.defaultWatchlist,
  );
  final _watchlistChanges = StreamController<List<String>>.broadcast();

  final Map<String, Quote> _latest = {};
  final _updates = StreamController<List<Quote>>.broadcast(sync: true);

  final Map<String, int> _watchers = {};
  List<Instrument>? _instruments;
  List<Instrument>? _cachedInstruments;

  @override
  void seedInstruments(List<Instrument> instruments) {
    _cachedInstruments = List.unmodifiable(instruments);
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
  Stream<List<String>> watchWatchlistIds() => _watchlistChanges.stream;

  @override
  void setWatchlist(List<String> ids) {
    _watchlistIds = List.unmodifiable(ids);
    _snapshots?.markStructuralDirty();
    _watchlistChanges.add(_watchlistIds);
  }

  @override
  Future<Result<Instrument>> getInstrument(String id) async {
    final cached = _instruments?.where((i) => i.id == id).firstOrNull;
    if (cached != null) return Success(cached);
    final response = await _api.call(instrumentEndpoint(id));
    return _parse(
      response,
      (json) => Instrument.fromJson(
        json['data'] is Map<String, Object?>
            ? json['data']! as Map<String, Object?>
            : json,
      ),
    );
  }

  // Filters run on the client: the full list is small and cached.
  @override
  Future<Result<List<Instrument>>> getInstruments({
    InstrumentKind? kind,
    String? underlying,
  }) async {
    final all = await _allInstruments();
    if (kind == null && underlying == null) return all;
    return all.map(
      (list) => [
        for (final i in list)
          if ((kind == null || i.kind == kind) &&
              (underlying == null || i.underlying == underlying))
            i,
      ],
    );
  }

  Future<Result<List<Instrument>>> _allInstruments() async {
    final cached = _instruments;
    if (cached != null) return Success(cached);
    final result = await _api.call(instrumentsEndpoint);
    if (result is Failure && _cachedInstruments != null) {
      return Success(_cachedInstruments!);
    }
    return _parse(result, (json) {
      final list = [
        for (final i in json['data']! as List)
          Instrument.fromJson(i as Map<String, Object?>),
      ];
      return _instruments = list;
    });
  }

  @override
  Instrument? instrument(String symbol) =>
      _instruments?.where((i) => i.symbol == symbol).firstOrNull;

  @override
  Future<Result<List<Quote>>> getQuotes(
    List<String> symbols, {
    bool full = false,
  }) async {
    final result = await _api.call(quotesEndpoint(symbols, full: full));
    return _parse(
      result,
      (json) => [
        for (final q in json['data']! as List)
          _merge(q as Map<String, Object?>),
      ],
    );
  }

  @override
  Future<Result<List<Candle>>> getCandles(
    String symbol,
    CandleInterval interval, {
    DateTime? from,
    int limit = 2000,
  }) async {
    final result = await _api.call(
      candlesEndpoint(symbol, interval, limit: limit, from: from),
    );
    return _parse(
      result,
      (json) => [
        for (final c in json['data']! as List)
          Candle.fromJson(c as Map<String, Object?>),
      ],
    );
  }

  @override
  Stream<List<Quote>> watchQuotes(
    List<String> symbols,
    FeedMode mode, {
    int throttleMs = 250,
  }) {
    final wanted = symbols.toSet();
    SocketSubscription? handle;
    StreamSubscription<List<Quote>>? inner;
    // Single-subscription: cancelling its one listener releases it.
    // ignore: close_sinks
    late final StreamController<List<Quote>> controller;
    controller = StreamController<List<Quote>>(
      onListen: () {
        final cached = [for (final s in wanted) ?_latest[s]];
        if (cached.isNotEmpty) controller.add(cached);
        inner = _updates.stream
            .map(
              (batch) => batch.where((q) => wanted.contains(q.symbol)).toList(),
            )
            .where((batch) => batch.isNotEmpty)
            .listen(controller.add);
        for (final s in wanted) {
          _watchers[s] = (_watchers[s] ?? 0) + 1;
        }
        handle = _socket.subscribeQuotes(wanted, mode, throttleMs: throttleMs);
      },
      onCancel: () async {
        handle?.cancel();
        for (final s in wanted) {
          final n = (_watchers[s] ?? 1) - 1;
          n <= 0 ? _watchers.remove(s) : _watchers[s] = n;
        }
        await inner?.cancel();
      },
    );
    return controller.stream;
  }

  void _onMessage(Map<String, Object?> message) {
    if (_disposed) return;
    if (message['type'] == 'ticks') {
      final parsed = parseJson(
        () => [
          for (final raw in message['data']! as List)
            _merge({
              ...raw as Map<String, Object?>,
              'asOf': message['asOf'],
              'seq': message['seq'],
            }),
        ],
      );
      if (parsed case Success(:final value) when value.isNotEmpty) {
        _updates.add(value);
      }
    } else if (message['type'] == 'ka') {
      final parsed = parseJson(() {
        final asOf = DateTime.fromMillisecondsSinceEpoch(
          message['asOf']! as int,
          isUtc: true,
        );
        final seq = message['seq'] as int?;
        return [
          for (final id
              in (message['quotes'] as List? ?? const []).cast<String>())
            if (_latest[id] case final previous?)
              previous.copyWith(asOf: asOf, seq: seq ?? previous.seq),
        ];
      });
      if (parsed case Success(:final value) when value.isNotEmpty) {
        for (final q in value) {
          _latest[q.id] = q;
        }
        _updates.add(value);
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _removeResyncReloader();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _updates.close();
    await _watchlistChanges.close();
  }

  Future<void> _resync() async {
    if (_watchers.isEmpty) return;
    final result = await getQuotes(_watchers.keys.toList(), full: true);
    if (result case Success(:final value) when value.isNotEmpty && !_disposed) {
      _updates.add(value);
    }
  }

  Quote _merge(Map<String, Object?> json) {
    final symbol = json['s']! as String;
    final previous = _latest[symbol];
    if (previous == null) return _latest[symbol] = Quote.fromJson(json);
    final t = json['t'] as int?;
    if (!previous.fromCache &&
        t != null &&
        t < previous.lastTradeTime.millisecondsSinceEpoch) {
      return previous;
    }
    final merged = previous.mergeJson(json);
    // Server data replaces a cache seed: the quote may claim live again.
    return _latest[symbol] = merged.fromCache
        ? merged.copyWith(fromCache: false)
        : merged;
  }

  Result<T> _parse<T>(
    Result<Object?> result,
    T Function(Map<String, Object?> json) parse,
  ) => switch (result) {
    Failure(:final error) => Failure(error),
    Success(:final value) => parseJson(
      () => parse(value! as Map<String, Object?>),
    ),
  };
}
