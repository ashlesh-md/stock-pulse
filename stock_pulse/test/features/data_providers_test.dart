import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/alerts/data/live_alerts_repository.dart';
import 'package:stock_pulse/features/alerts/di/alerts_data_providers.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';
import 'package:stock_pulse/features/market/application/live_quote_provider.dart';
import 'package:stock_pulse/features/market/data/live_market_repository.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/more/data/funds_transfer_api.dart';
import 'package:stock_pulse/features/more/di/more_data_providers.dart';
import 'package:stock_pulse/features/options/data/live_chain_repository.dart';
import 'package:stock_pulse/features/options/di/options_data_providers.dart';
import 'package:stock_pulse/features/orders/data/live_order_repository.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/portfolio/data/live_portfolio_repository.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';

import '../helpers/fake_market_repository.dart';
import '../helpers/fake_market_socket.dart';
import '../helpers/fake_snapshot_store.dart';

void main() {
  late FakeMarketSocket socket;
  late ProviderContainer container;

  setUp(() {
    socket = FakeMarketSocket();
    container = ProviderContainer(
      overrides: [
        // Port 1: nothing listens, even when a dev server runs on 8080.
        appConfigProvider.overrideWithValue(
          const AppConfig(host: '127.0.0.1', port: 1),
        ),
        marketSocketProvider.overrideWithValue(socket),
        snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('each feature DI file builds its Live repository', () {
    expect(
      container.read(marketRepositoryProvider),
      isA<LiveMarketRepository>(),
    );
    expect(container.read(chainRepositoryProvider), isA<LiveChainRepository>());
    expect(container.read(orderRepositoryProvider), isA<LiveOrderRepository>());
    expect(
      container.read(portfolioRepositoryProvider),
      isA<LivePortfolioRepository>(),
    );
    expect(
      container.read(alertsRepositoryProvider),
      isA<LiveAlertsRepository>(),
    );
    expect(container.read(fundsTransferProvider), isA<FundsTransferApi>());
  });

  test('socket and network status follow the socket', () async {
    final statuses = <SocketStatus?>[];
    final network = <NetworkStatus?>[];
    container
      ..listen(socketStatusProvider, (_, s) => statuses.add(s.value))
      ..listen(networkStatusProvider, (_, s) => network.add(s.value));
    await Future<void>.delayed(Duration.zero);
    socket.setStatus(const SocketConnected(sessionId: 'S1'));
    await Future<void>.delayed(Duration.zero);
    expect(statuses.last, isA<SocketConnected>());
    expect(network, [NetworkStatus.reconnecting, NetworkStatus.live]);
  });

  test('liveQuoteProvider emits each quote of its id', () async {
    final repo = FakeMarketRepository();
    final c = ProviderContainer(
      overrides: [marketRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(
      liveQuoteProvider((id: 'TCS', throttleMs: 250)),
      (_, _) {},
    );
    final quote = Quote(
      symbol: 'TCS',
      ltp: 10,
      change: 0,
      changePercent: 0,
      lastTradeTime: DateTime.utc(2026),
    );
    await Future<void>.delayed(Duration.zero);
    repo.push([quote]);
    await Future<void>.delayed(Duration.zero);
    expect(sub.read().value, quote);
    expect(repo.watchCalls.single.throttleMs, 250);
  });

  group('repository transport failures', () {
    test('chains propagate REST failures and release their range', () async {
      final chains = container.read(chainRepositoryProvider);
      expect(
        ((await chains.expiries('NIFTY')) as Failure).error,
        isA<Object>(),
      );
      expect(await chains.getChain('NIFTY', 'e'), isA<Failure<Object?>>());

      const req = ChainRequest(
        underlying: 'NIFTY',
        expiry: '2026-11-10',
        fromStrike: 1,
        toStrike: 9,
      );
      final feed = chains.watchChain(req);
      final listening = feed.views.listen((_) {}, onError: (Object _) {});
      feed.setVisibleRange(2, 8);
      await Future<void>.delayed(const Duration(milliseconds: 260));
      expect(socket.chainSubs.single.fromStrike, 2);
      await listening.cancel();
      expect(socket.chainSubs.single.isCancelled, isTrue);
    });

    test('alerts propagate errors and release account holders', () async {
      final alerts = container.read(alertsRepositoryProvider);
      expect(await alerts.list(), isA<Failure<List<PriceAlert>>>());
      expect(
        await alerts.create('TCS', AlertCondition.above, 1),
        isA<Failure<PriceAlert>>(),
      );
      expect(await alerts.delete('A1'), isA<Failure<PriceAlert>>());
      final all = alerts.watchAll().listen((_) {}, onError: (Object _) {});
      final triggered = alerts.triggered.listen((_) {}, onError: (Object _) {});
      await Future<void>.delayed(Duration.zero);
      expect(socket.accountSubs.where((s) => !s.isCancelled), hasLength(2));
      await all.cancel();
      await triggered.cancel();
      expect(socket.accountSubs.every((s) => s.isCancelled), isTrue);
    });
  });
}
