import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/di/drawings_providers.dart';
import 'package:stock_pulse/features/chart/domain/chart_layout.dart';
import 'package:stock_pulse/features/chart/domain/chart_prefs.dart';
import 'package:stock_pulse/features/chart/domain/chart_state.dart';
import 'package:stock_pulse/features/market/application/stock_detail_state.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

/// Chart settings and crosshair state for one instrument. Candle loading and
/// live aggregation stay in the stock-detail feed controller.
class ChartController extends AsyncNotifier<ChartState> {
  ChartController(this.instrumentId);

  final String instrumentId;
  Future<void> _prefsWrites = Future.value();

  @override
  Future<ChartState> build() async {
    final detailProvider = stockDetailControllerProvider(instrumentId);
    final (detail, layout, prefs) = await (
      ref.read(detailProvider.future),
      ref.read(chartStoreProvider).load(instrumentId),
      ref.read(chartStoreProvider).loadPrefs(),
    ).wait;
    final initial = _fromStockDetail(detail).copyWith(
      layout: layout,
      logScale: prefs.logScale,
      gridlines: prefs.gridlines,
    );
    if (!ref.mounted) return initial;
    ref.listen(
      drawingsControllerProvider(instrumentId).select((s) => s.drawings),
      (_, _) => _syncLayout(),
    );
    ref.listen(
      studiesControllerProvider(instrumentId),
      (_, _) => _syncLayout(),
    );
    // Only range, interval and type are mirrored; skipping unchanged values
    // keeps a detail rebuild during a widget build from writing chart state.
    ref.listen(
      detailProvider.select(
        (a) => a.whenData((d) => (d.range, d.interval, d.chartType)),
      ),
      (_, next) {
        if (!next.hasValue || !ref.mounted) return;
        final current = state.value;
        final detail = ref.read(detailProvider).requireValue;
        state = AsyncData(_fromStockDetail(detail, previous: current));
      },
    );
    return initial;
  }

  void _syncLayout() {
    setLayout(
      ChartLayout(
        drawings: ref.read(drawingsControllerProvider(instrumentId)).drawings,
        studies: ref.read(studiesControllerProvider(instrumentId)),
      ),
    );
  }

  void openedFullscreen() =>
      ref.read(analyticsProvider).log(Events.chartFullscreen);

  Future<void> setLogScale({required bool enabled}) =>
      _updatePrefs(logScale: enabled);

  Future<void> setGridlines({required bool enabled}) =>
      _updatePrefs(gridlines: enabled);

  Future<void> _updatePrefs({bool? logScale, bool? gridlines}) async {
    final current = state.value;
    if (current == null) return;
    final next = current.copyWith(logScale: logScale, gridlines: gridlines);
    if (next == current) return;
    state = AsyncData(next);
    ref
        .read(analyticsProvider)
        .log(
          Events.chartSettingChanged(
            logScale != null ? 'logScale' : 'gridlines',
            '${logScale ?? gridlines}',
          ),
        );
    await _savePrefs(
      (prefs) => prefs.copyWith(logScale: logScale, gridlines: gridlines),
    );
  }

  Future<void> _savePrefs(ChartPrefs Function(ChartPrefs) update) {
    final store = ref.read(chartStoreProvider);
    _prefsWrites = _prefsWrites.then((_) async {
      final current = await store.loadPrefs();
      await store.savePrefs(update(current));
    });
    return _prefsWrites;
  }

  Future<void> selectRange(ChartRange range) async {
    if (!state.hasValue) await future;
    await ref
        .read(stockDetailControllerProvider(instrumentId).notifier)
        .selectRange(range);
    await _savePrefs(
      (prefs) => prefs.copyWith(range: range, interval: range.defaultInterval),
    );
  }

  Future<void> selectInterval(CandleInterval interval) async {
    if (!state.hasValue) await future;
    await ref
        .read(stockDetailControllerProvider(instrumentId).notifier)
        .selectInterval(interval);
    await _savePrefs((prefs) => prefs.copyWith(interval: interval));
  }

  Future<void> selectType(ChartType type) async {
    if (!state.hasValue) await future;
    ref
        .read(stockDetailControllerProvider(instrumentId).notifier)
        .selectChartType(type);
    await _savePrefs((prefs) => prefs.copyWith(type: type));
  }

  ChartState _fromStockDetail(StockDetailState detail, {ChartState? previous}) {
    return ChartState(
      range: detail.range,
      interval: detail.interval,
      type: detail.chartType,
      crosshairIndex: previous?.crosshairIndex,
      layout: previous?.layout ?? ChartLayout(),
      logScale: previous?.logScale ?? false,
      gridlines: previous?.gridlines ?? true,
    );
  }

  void setCrosshair(int? index) {
    final current = state.value;
    if (current == null || current.crosshairIndex == index) return;
    state = AsyncData(current.copyWith(crosshairIndex: index));
  }

  void setLayout(ChartLayout layout) {
    final current = state.value;
    if (current == null || current.layout == layout) return;
    state = AsyncData(current.copyWith(layout: layout));
  }
}
