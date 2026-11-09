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
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
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
  final now = DateTime.utc(2026, 11, 8, 4);
  const tcs = Instrument(
    symbol: 'TCS',
    name: 'TCS',
    exchange: 'NSE',
    sector: '',
    tickSize: .05,
    lotSize: 1,
  );

  Future<TicketBlock?> preflightWithFunds(double available) async {
    final portfolio = _Portfolio();
    when(() => portfolio.current).thenReturn(
      PortfolioBook(
        positions: const [],
        holdings: const [],
        funds: Funds(available: available),
      ),
    );
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
        serverClockProvider.overrideWithValue(ServerClock(FakeClock(now))),
        networkStatusProvider.overrideWith(
          (ref) => Stream.value(NetworkStatus.live),
        ),
        marketRepositoryProvider.overrideWithValue(
          FakeMarketRepository(
            instruments: const [tcs],
            quotes: [
              Quote(
                symbol: 'TCS',
                ltp: 100,
                change: 0,
                changePercent: 0,
                lastTradeTime: now,
              ),
            ],
          ),
        ),
        localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
        portfolioRepositoryProvider.overrideWithValue(portfolio),
      ],
    );
    container
      ..listen(marketClockProvider, (_, _) {})
      ..listen(networkStatusProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    return container.read(orderPreflightProvider)(
      symbol: 'TCS',
      side: OrderSide.buy,
      type: OrderType.market,
      product: ProductType.cnc,
      quantity: 2,
    );
  }

  test('preflight blocks a buy that costs more than available funds', () async {
    expect(await preflightWithFunds(150), TicketBlock.funds);
  });

  test('preflight passes a buy that available funds cover', () async {
    expect(await preflightWithFunds(500), isNull);
  });
}
