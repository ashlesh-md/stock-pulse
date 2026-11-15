import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

void main() {
  test('stock chart query selects its range and allowed interval', () {
    final route =
        AppRoute.fromUri(Uri.parse('/stock/RELIANCE?range=1W&interval=15m'))!
            as StockRoute;

    expect(route.instrumentId, 'RELIANCE');
    expect(route.selection?.range, ChartRange.w1);
    expect(route.selection?.interval, CandleInterval.m15);
    expect(AppRoute.fromUri(Uri.parse(route.location)), route);
  });

  test('unknown chart query values silently use the valid default', () {
    final route =
        AppRoute.fromUri(Uri.parse('/stock/RELIANCE?range=bad&interval=bad'))!
            as StockRoute;

    expect(route.selection?.range, ChartRange.d1);
    expect(route.selection?.interval, ChartRange.d1.defaultInterval);
  });
}
