import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/chart/application/chart_controller.dart';
import 'package:stock_pulse/features/chart/domain/chart_state.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

final chartControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChartController, ChartState, String>(ChartController.new);

/// The candle under the crosshair, or the latest one. It lists its
/// dependencies so it resolves inside the stock page's scope, where the
/// page's own chart and detail controllers live.
final chartReadoutProvider = Provider.autoDispose
    .family<(Candle?, double?), String>(
      dependencies: [chartControllerProvider, stockDetailControllerProvider],
      (ref, id) {
        final index = ref.watch(
          chartControllerProvider(id).select((s) => s.value?.crosshairIndex),
        );
        return ref.watch(
          stockDetailControllerProvider(id).select((s) {
            final detail = s.value;
            if (detail == null || detail.candles.isEmpty) return (null, null);
            final i = (index ?? detail.candles.length - 1).clamp(
              0,
              detail.candles.length - 1,
            );
            return (
              detail.candles[i],
              i > 0 ? detail.candles[i - 1].close : detail.quote.prevClose,
            );
          }),
        );
      },
    );
