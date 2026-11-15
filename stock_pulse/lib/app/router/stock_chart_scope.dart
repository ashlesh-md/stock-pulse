import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/chart/application/chart_controller.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_route_providers.dart';
import 'package:stock_pulse/features/chart/domain/chart_prefs.dart';
import 'package:stock_pulse/features/chart/domain/chart_selection.dart';
import 'package:stock_pulse/features/market/application/stock_detail_controller.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';

class StockChartScope extends ConsumerStatefulWidget {
  const StockChartScope({
    super.key,
    required this.instrumentId,
    required this.selection,
    required this.child,
  });
  final String instrumentId;
  final ChartSelection? selection;
  final Widget child;
  @override
  ConsumerState<StockChartScope> createState() => _StockChartScopeState();
}

class _StockChartScopeState extends ConsumerState<StockChartScope> {
  late final _id = widget.instrumentId;
  late final _selection = widget.selection;
  late final Future<ChartPrefs> _prefs = ref
      .read(chartStoreProvider)
      .loadPrefs();
  @override
  Widget build(BuildContext context) => FutureBuilder<ChartPrefs>(
    future: _prefs,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox.expand();
      }
      final prefs = snapshot.data ?? const ChartPrefs();
      final selection = _selection == null
          ? ChartSelection(
              range: prefs.range,
              interval: prefs.interval,
              type: prefs.type,
            )
          : ChartSelection(
              range: _selection.range,
              interval: _selection.interval,
              type: _selection.type ?? prefs.type,
            );
      return ProviderScope(
        retry: (_, _) => null,
        overrides: [
          initialChartSelectionProvider(_id).overrideWithValue(selection),
          stockDetailControllerProvider(_id)
              .overrideWith(() => StockDetailController(_id)),
          chartControllerProvider(_id).overrideWith(() => ChartController(_id)),
        ],
        child: widget.child,
      );
    },
  );
}
