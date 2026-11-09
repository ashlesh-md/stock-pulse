import 'dart:async';
import 'dart:math';

import 'package:market_server/src/candle_math.dart';
import 'package:market_server/src/clock_scheduler.dart';
import 'package:market_server/src/history_seed.dart';
import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/market_clock.dart';
import 'package:market_server/src/models.dart';
import 'package:market_server/src/stock_state.dart';
import 'package:market_server/src/time_buckets.dart';

export 'package:market_server/src/stock_state.dart';

class MarketEngine {
  MarketEngine(
    List<Instrument> instruments, {
    Random? random,
    DateTime Function()? clock,
    MarketClock? marketClock,
    this.calendar,
    this.scheduler,
    this.tickInterval = const Duration(milliseconds: 200),
    this.load = false,
    int intradayDays = 7,
    int dailyDays = 5 * 365,
  }) : _random = random ?? Random(),
       _clock =
           marketClock?.marketNow ?? clock ?? (() => DateTime.now().toUtc()) {
    for (final instrument in instruments) {
      final stock = StockState(instrument);
      _stocks[instrument.symbol] = stock;
      seedHistory(
        stock,
        now: _clock(),
        random: _random,
        intradayDays: intradayDays,
        dailyDays: dailyDays,
      );
      _rebuildDepth(stock);
      if (instrument.kind == InstrumentKind.marketIndex) {
        // An index has no order book and no volume of its own.
        _indices.add(stock);
        stock
          ..bids = const []
          ..asks = const [];
        for (final c in [...stock.minutes, ...stock.daily]) {
          c.volume = 0;
        }
      }
    }
    // Index level = base × Σ w·(ltp / seed ltp) / Σ w over constituents.
    for (final s in _stocks.values) {
      if (s.instrument.weight > 0) _seedLtp[s.id] = s.ltp;
    }
  }

  static const maxMinuteCandles = 12000;

  final Random _random;
  final DateTime Function() _clock;
  final MarketCalendar? calendar;

  final ClockScheduler? scheduler;
  final Duration tickInterval;
  final bool load;
  void Function(Set<String>, DateTime)? afterEquities;
  final Map<String, StockState> _stocks = {};
  final List<StockState> _indices = [];
  final Map<String, double> _seedLtp = {};
  final _ticks = StreamController<Set<String>>.broadcast(sync: true);
  Timer? _timer;

  Stream<Set<String>> get ticks => _ticks.stream;

  Iterable<StockState> get stocks => _stocks.values;
  StockState? operator [](String symbol) => _stocks[symbol];

  void ensureOption(Instrument instrument) {
    _stocks.putIfAbsent(instrument.symbol, () {
      final stock = StockState(instrument);
      stock.ltp = instrument.basePrice;
      for (var day = -1; day <= 0; day++) {
        stock.daily.add(
          Candle(
            start: bucketStart(
              _clock().add(Duration(days: day)),
              const Duration(days: 1),
            ),
            open: stock.ltp,
            high: stock.ltp,
            low: stock.ltp,
            close: stock.ltp,
            volume: 0,
          ),
        );
      }
      stock.lastTradeTime = _clock();
      _rebuildDepth(stock);
      return stock;
    });
  }

  void repriceOption(String id, double price, DateTime now) {
    final stock = _stocks[id]!;
    stock.ltp = price;
    stock.lastTradeTime = now;
    _rebuildDepth(stock);
  }

  void start() => _timer ??= Timer.periodic(tickInterval, (_) => step());

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _ticks.close();
  }

  MarketPhase get phase => calendar?.phaseAt(_clock()) ?? MarketPhase.open;

  void step() {
    scheduler?.tick();
    final now = _clock();
    final phase = this.phase;
    if (phase == MarketPhase.closed) return;
    final changed = <String>{};
    for (final stock in _stocks.values) {
      if (stock.instrument.kind != InstrumentKind.equity) continue;
      // Not every stock trades every 200 ms; illiquid ones tick less.
      if (!load && _random.nextDouble() > 0.55) continue;
      if (phase == MarketPhase.preOpen) {
        _moveIep(stock);
      } else {
        _trade(stock, now);
      }
      changed.add(stock.instrument.symbol);
    }
    if (phase == MarketPhase.open && changed.isNotEmpty) {
      for (final index in _indices) {
        if (_recomputeIndex(index, now)) changed.add(index.id);
      }
    }
    afterEquities?.call(changed, now);
    if (changed.isNotEmpty) _ticks.add(changed);
  }

  void rollDay(BoundaryEvent e) {
    final bucket = bucketStart(e.at, const Duration(days: 1));
    for (final stock in _stocks.values) {
      stock.iep = null;
      addToCandles(stock.daily, bucket, stock.ltp, 0);
    }
  }

  void openMarket(BoundaryEvent e) {
    final bucket = bucketStart(e.at, const Duration(days: 1));
    for (final stock in _stocks.values) {
      final iep = stock.iep;
      if (iep == null) continue;
      stock
        ..iep = null
        ..ltp = iep;
      final today = stock.daily.isEmpty ? null : stock.daily.last;
      if (today == null || today.start != bucket) {
        addToCandles(stock.daily, bucket, iep, 0);
      } else if (today.volume == 0) {
        today
          ..open = iep
          ..high = iep
          ..low = iep
          ..close = iep;
      } else {
        // Seeded history can already hold today's candle.
        today
          ..open = iep
          ..high = max(today.high, iep)
          ..low = min(today.low, iep)
          ..close = iep;
      }
      _rebuildDepth(stock);
    }
  }

  Map<String, Object?> quoteJson(StockState s, FeedMode mode) =>
      s.toQuoteJson(mode);

  List<Candle> candles(
    String symbol,
    Duration interval, {
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) {
    final stock = _stocks[symbol];
    if (stock == null) return const [];
    return aggregateCandles(stock, interval, from: from, to: to, limit: limit);
  }

  bool _recomputeIndex(StockState index, DateTime now) {
    var sumW = 0.0, sum = 0.0;
    for (final e in _seedLtp.entries) {
      final s = _stocks[e.key]!;
      sumW += s.instrument.weight;
      sum += s.instrument.weight * s.ltp / e.value;
    }
    if (sumW == 0) return false;
    final level = roundToTick(
      index.instrument.basePrice * sum / sumW,
      index.instrument.tickSize,
    );
    if (level == index.ltp) return false;
    index
      ..ltp = level
      ..lastQuantity = 0
      ..lastTradeTime = now;
    addToCandles(
      index.minutes,
      bucketStart(now, const Duration(minutes: 1)),
      level,
      0,
      cap: maxMinuteCandles,
    );
    addToCandles(
      index.daily,
      bucketStart(now, const Duration(days: 1)),
      level,
      0,
    );
    index
      ..bids = const []
      ..asks = const [];
    return true;
  }

  void _moveIep(StockState stock) {
    const sigma = 0.00012 * 0.3;
    final from = stock.iep ?? stock.ltp;
    stock.iep = roundToTick(
      from * (1 + sigma * gaussian(_random)),
      stock.instrument.tickSize,
    );
  }

  void _trade(StockState stock, DateTime now) {
    // Geometric random walk: each step moves the price by a small normally
    // distributed percentage, with a slight pull back toward prevClose so
    // prices don't drift off forever during a long session.
    const sigma = 0.00012; // ≈0.15% per minute at ~3 trades/s
    final pull = (stock.prevClose - stock.ltp) / stock.prevClose * 0.002;
    final step = pull + sigma * gaussian(_random);
    final price = roundToTick(
      stock.ltp * (1 + step),
      stock.instrument.tickSize,
    );
    final qty = 1 + _random.nextInt(_random.nextDouble() < 0.1 ? 2000 : 150);

    stock
      ..ltp = price
      ..lastQuantity = qty
      ..lastTradeTime = now;
    addToCandles(
      stock.minutes,
      bucketStart(now, const Duration(minutes: 1)),
      price,
      qty,
      cap: maxMinuteCandles,
    );
    // A trade after IST midnight starts a new daily candle: yesterday's close
    // becomes the new prevClose automatically (see StockState.prevClose).
    addToCandles(
      stock.daily,
      bucketStart(now, const Duration(days: 1)),
      price,
      qty,
    );
    _rebuildDepth(stock);
  }

  void _rebuildDepth(StockState stock) {
    final tick = stock.instrument.tickSize;
    final spreadTicks = 1 + _random.nextInt(3);
    final bestBid = roundToTick(stock.ltp - tick * (spreadTicks ~/ 2), tick);
    final bestAsk = roundToTick(bestBid + tick * spreadTicks, tick);
    DepthLevel level(double price) =>
        DepthLevel(price, 10 + _random.nextInt(900), 1 + _random.nextInt(25));
    stock
      ..bids = [
        for (var i = 0; i < 5; i++)
          level(roundToTick(bestBid - tick * i, tick)),
      ]
      ..asks = [
        for (var i = 0; i < 5; i++)
          level(roundToTick(bestAsk + tick * i, tick)),
      ];
  }
}
