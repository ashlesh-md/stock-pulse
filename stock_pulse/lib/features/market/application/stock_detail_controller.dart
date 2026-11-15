import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/features/chart/di/chart_route_providers.dart';
import 'package:stock_pulse/features/market/application/stock_detail_state.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

/// The one controller for the stock detail screen: quote, chart (range,
/// interval, type), depth, and placing orders.
class StockDetailController extends AsyncNotifier<StockDetailState> {
  StockDetailController(this.symbol);

  final String symbol;

  /// Day volume from the previous quote. A candle needs the volume of THIS
  /// trade, but the feed sends cumulative day volume, so we take the
  /// difference.
  int? _lastVolume;

  /// Increases on every chart load. Tapping 1Y then quickly 5Y starts two
  /// requests; only the newest may write state, whichever answers last.
  int _chartRequest = 0;

  @override
  Future<StockDetailState> build() async {
    final repo = ref.watch(marketRepositoryProvider);
    final selection = ref.watch(initialChartSelectionProvider(symbol));
    final range = selection?.range ?? ChartRange.d1;
    final interval = selection?.interval ?? range.defaultInterval;
    final chartType = selection?.type ?? ChartType.candles;
    // Both requests in parallel: the screen waits for the slower one, not
    // the sum of both.
    final (instrument, candles, quotes) = await (
      repo.getInstrument(symbol),
      repo.getCandles(
        symbol,
        interval,
        from: range.from(DateTime.now().toUtc()),
      ),
      repo.getQuotes([symbol], full: true),
    ).wait;
    final loadedInstrument = instrument.getOrThrow();
    final quote = quotes.getOrThrow().single;
    final (loadedCandles, previousSession) = await _chartCandles(
      repo,
      range,
      interval,
      quote.lastTradeTime,
      candles.getOrThrow(),
    );
    final loaded = StockDetailState(
      instrument: loadedInstrument,
      quote: quote,
      range: range,
      interval: interval,
      chartType: chartType,
      candles: loadedCandles,
      previousSession: previousSession,
    );
    if (!ref.mounted) return loaded;
    ref.read(analyticsProvider).log(Events.chartOpened);
    _lastVolume = quote.volume;

    // `full` mode: this screen shows the order book.
    final sub = repo.watchQuotes([symbol], FeedMode.full).listen(_onQuote);
    ref.onDispose(sub.cancel);
    return loaded;
  }

  /// 1D, 1W … 5Y. Switches to that range's default interval.
  Future<void> selectRange(ChartRange range) async {
    final current = state.value;
    if (current == null || current.range == range) return;
    ref
        .read(analyticsProvider)
        .log(Events.chartSettingChanged('range', range.name));
    await _loadChart(range, range.defaultInterval);
  }

  /// Candle size inside the current range (only the range's allowed ones).
  Future<void> selectInterval(CandleInterval interval) async {
    final current = state.value;
    if (current == null ||
        current.interval == interval ||
        !current.range.intervals.contains(interval)) {
      return;
    }
    ref
        .read(analyticsProvider)
        .log(Events.chartSettingChanged('interval', interval.apiName));
    await _loadChart(current.range, interval);
  }

  /// Candles, Heikin-Ashi, OHLC, line, area: same data, drawn differently,
  /// so no reload.
  void selectChartType(ChartType type) {
    final current = state.value;
    if (current == null || current.chartType == type) return;
    ref
        .read(analyticsProvider)
        .log(Events.chartSettingChanged('type', type.name));
    state = AsyncData(current.copyWith(chartType: type));
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    try {
      await future;
    } on AppError {
      return;
    }
  }

  Future<void> _loadChart(ChartRange range, CandleInterval interval) async {
    final request = ++_chartRequest;
    // Range and interval change only when the new candles arrive, so the
    // candles on screen always match `interval` (live ticks fold into them
    // correctly) and the chips never point at data that is not shown yet.
    state = AsyncData(
      state.requireValue.copyWith(loadingCandles: true, candlesFailed: false),
    );
    final repo = ref.read(marketRepositoryProvider);
    final current = state.requireValue;
    final initial = await repo.getCandles(
      symbol,
      interval,
      from: range.from(DateTime.now().toUtc()),
    );
    final List<Candle> candles;
    final bool previousSession;
    switch (initial) {
      case Success(:final value):
        (candles, previousSession) = await _chartCandles(
          repo,
          range,
          interval,
          current.quote.lastTradeTime,
          value,
        );
      case Failure():
        if (ref.mounted && request == _chartRequest) {
          state = AsyncData(
            state.requireValue.copyWith(
              loadingCandles: false,
              candlesFailed: true,
            ),
          );
        }
        return;
    }
    // The user may have picked something else meanwhile, or left the screen.
    if (!ref.mounted || request != _chartRequest) return;
    final latest = state.requireValue;
    state = AsyncData(
      latest.copyWith(
        range: range,
        interval: interval,
        candles: candles,
        previousSession: previousSession,
        loadingCandles: false,
        candlesFailed: false,
      ),
    );
  }

  Future<(List<Candle>, bool)> _chartCandles(
    MarketRepository repo,
    ChartRange range,
    CandleInterval interval,
    DateTime lastTradeTime,
    List<Candle> candles,
  ) async {
    if (range != ChartRange.d1 || candles.isNotEmpty) return (candles, false);
    final result = await repo.getCandles(
      symbol,
      interval,
      from: CandleInterval.d1.bucketOf(lastTradeTime),
    );
    return switch (result) {
      Success(:final value) => (value, value.isNotEmpty),
      Failure() => (const <Candle>[], false),
    };
  }

  void _onQuote(List<Quote> batch) {
    final current = state.value;
    if (current == null) return;
    final quote = batch.last;
    final isNewTrade = quote.lastTradeTime.isAfter(current.quote.lastTradeTime);
    if (!isNewTrade) {
      // Same trade (a snapshot repeat or a depth-only change).
      state = AsyncData(current.copyWith(quote: quote));
      return;
    }
    final volume = quote.volume;
    final delta = volume == null || _lastVolume == null
        ? 0
        : max(0, volume - _lastVolume!);
    _lastVolume = volume ?? _lastVolume;
    state = AsyncData(
      current.copyWith(
        quote: quote,
        candles: applyTrade(
          current.candles,
          current.interval,
          price: quote.ltp,
          time: quote.lastTradeTime,
          volumeDelta: delta,
        ),
      ),
    );
  }
}
