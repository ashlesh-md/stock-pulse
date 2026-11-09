import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_server/market_server.dart' show instruments;
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/orders/domain/order.dart'
    show OrderSide, OrderStatus, OrderType;
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';

import '../helpers/fake_crash_reporter.dart';
import '../helpers/fake_pending_order_store.dart';
import '../helpers/fake_snapshot_store.dart';
import '../helpers/test_server.dart';

/// Controllers wired to the real server through the real providers; only
/// the config is overridden to point at the test port.
void main() {
  late TestServer server;
  late ProviderContainer container;

  setUp(() async {
    server = await TestServer.start();
    container = ProviderContainer(
      overrides: [
        analyticsProvider.overrideWithValue(
          AnalyticsService(const [], FakeCrashReporter(), consent: () => true),
        ),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        appConfigProvider.overrideWithValue(server.config),
        snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
        fakePendingOrderStoreOverride(),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await server.close();
  });

  test(
    'watchlist: REST snapshot first, then live ticks update quotes',
    () async {
      final sub = container.listen(watchlistControllerProvider, (_, _) {});
      final initial = await container.read(watchlistControllerProvider.future);
      expect(initial.instruments, hasLength(instruments.length));
      expect(initial.quotes, hasLength(instruments.length));

      final before = Map.of(initial.quotes);
      await eventually(() {
        server.step();
        final now = container
            .read(watchlistControllerProvider)
            .requireValue
            .quotes;
        return now.entries.any((e) => e.value != before[e.key]);
      });

      sub.close();
    },
  );

  test('closing the watchlist unsubscribes on the server', () async {
    final sub = container.listen(watchlistControllerProvider, (_, _) {});
    await container.read(watchlistControllerProvider.future);
    final socket = container.read(marketSocketProvider);
    final frames = <String>[];
    socket.frames.where((f) => f.outgoing).listen((f) => frames.add(f.text));

    sub.close(); // the screen went away → autoDispose
    await eventually(() => frames.any((f) => f.contains('"unsubscribe"')));
  });

  test('stock detail: live trades update the last candle; ranges, intervals, chart types', () async {
    final provider = stockDetailControllerProvider('TCS');
    final sub = container.listen(provider, (_, _) {});
    final initial = await container.read(provider.future);
    expect(initial.candles, isNotEmpty);
    expect(
      initial.quote.bids,
      hasLength(5),
      reason: 'full mode includes depth',
    );

    await eventually(() {
      server.step();
      final s = container.read(provider).requireValue;
      return s.quote.lastTradeTime.isAfter(initial.quote.lastTradeTime);
    });
    final live = container.read(provider).requireValue;
    expect(live.candles.last.close, live.quote.ltp);

    expect(initial.range, ChartRange.d1);
    expect(initial.interval, CandleInterval.m5);

    // 1Y → daily candles from about a year ago.
    await container.read(provider.notifier).selectRange(ChartRange.y1);
    final year = container.read(provider).requireValue;
    expect(year.interval, CandleInterval.d1);
    expect(year.loadingCandles, isFalse);
    expect(year.candles.length, inInclusiveRange(360, 367));
    expect(year.rangeChangePercent, isNotNull);

    // Weekly inside 1Y: ~52 candles.
    await container.read(provider.notifier).selectInterval(CandleInterval.w1);
    final weekly = container.read(provider).requireValue;
    expect(weekly.candles.length, inInclusiveRange(52, 54));

    // An interval the range does not allow is ignored.
    await container.read(provider.notifier).selectInterval(CandleInterval.m1);
    expect(container.read(provider).requireValue.interval, CandleInterval.w1);

    // Chart type: drawn differently, same candles, no reload.
    container.read(provider.notifier).selectChartType(ChartType.area);
    final area = container.read(provider).requireValue;
    expect(area.chartType, ChartType.area);
    expect(identical(area.candles, weekly.candles), isTrue);
    sub.close();
  });

  test(
    'portfolio: a fill pushed over the socket updates orders and positions',
    () async {
      final sub = container.listen(portfolioControllerProvider, (_, _) {});
      final initial = await container.read(portfolioControllerProvider.future);
      expect(initial.orders, isEmpty);

      final result = await container
          .read(portfolioRepositoryProvider)
          .placeOrder(
            symbol: 'INFY',
            side: OrderSide.buy,
            type: OrderType.market,
            quantity: 4,
          );
      expect(result, isNotNull);

      await eventually(() {
        final s = container.read(portfolioControllerProvider).requireValue;
        return s.orders.length == 1 && s.positions.length == 1;
      });
      final s = container.read(portfolioControllerProvider).requireValue;
      expect(s.orders.single.status, OrderStatus.complete);
      expect(s.positions.single.quantity, 4);

      // Live P&L needs a price for the position.
      await eventually(() {
        server.step();
        return container
            .read(portfolioControllerProvider)
            .requireValue
            .ltp
            .containsKey('INFY');
      });
      sub.close();
    },
  );
}
