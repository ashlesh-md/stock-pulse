import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/market_time/domain/server_clock.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/orders/di/order_preflight_provider.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/ticket_validation.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

import '../../helpers/fake_local_prefs.dart';
import '../../helpers/fake_market_repository.dart';

class _Portfolio extends Mock implements PortfolioRepository {}

void main() {
  test('preflight is unavailable while the market clock has not arrived', () {
    final container = ProviderContainer.test(
      overrides: [
        marketClockProvider.overrideWith((ref) => const Stream.empty()),
        marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
      ],
    );
    expect(
      container.read(orderPreflightProvider)(
        symbol: 'TCS',
        side: OrderSide.buy,
        type: OrderType.market,
        product: ProductType.cnc,
        quantity: 1,
      ),
      TicketBlock.unavailable,
    );
  });

  test(
    'preflight reads live context and quote data before returning block',
    () async {
      final portfolio = _Portfolio();
      when(() => portfolio.current).thenReturn(
        PortfolioBook(
          positions: const [],
          holdings: const [],
          funds: const Funds(available: 100000),
        ),
      );
      final clock = FakeClock(DateTime.utc(2026, 11, 8, 4));
      final container = ProviderContainer.test(
        overrides: [
          marketClockProvider.overrideWith(
            (ref) => Stream.value(
              const MarketClockState(
                phase: MarketPhase.open,
                marketOffsetMs: 0,
                mode: 'real',
                tradingDay: '2026-11-08',
              ),
            ),
          ),
          serverClockProvider.overrideWithValue(ServerClock(clock)),
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(NetworkStatus.live),
          ),
          marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
          localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
          portfolioRepositoryProvider.overrideWithValue(portfolio),
        ],
      );
      container.listen(marketClockProvider, (_, _) {});
      container.listen(networkStatusProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final result = container.read(orderPreflightProvider)(
        symbol: 'TCS',
        side: OrderSide.buy,
        type: OrderType.market,
        product: ProductType.cnc,
        quantity: 1,
      );
      expect(result, TicketBlock.unavailable);
      verify(() => portfolio.current).called(1);
    },
  );
}
