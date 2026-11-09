import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/features/orders/domain/order.dart'
    show OrderSide, ProductType;
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart'
    show OrderSource, OrderTicketArgs;
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';

void main() {
  test('each route builds its location', () {
    expect(const WatchlistRoute().location, '/watchlist');
    expect(const AiChatRoute().location, '/ai');
    expect(const MoreRoute().location, '/more');
    expect(const StrategyRoute().location, '/strategy');
    expect(const SocketLabRoute().location, '/more/socket-lab');
    expect(const AddFundsRoute().location, '/more/add-funds');
    expect(const StockRoute('M&M').location, '/stock/M%26M');
    expect(const OptionChainRoute().location, '/options');
    expect(
      const OptionChainRoute(
        underlying: 'NIFTY',
        expiry: '2026-11-10',
      ).location,
      '/options?u=NIFTY&e=2026-11-10',
    );
    expect(const PortfolioRoute().location, '/portfolio');
    expect(
      const PortfolioRoute(section: PortfolioSection.orders).location,
      '/portfolio?tab=orders',
    );
  });

  test('only the five shell routes are tabs', () {
    expect(
      [
        const WatchlistRoute(),
        const OptionChainRoute(),
        const AiChatRoute(),
        const PortfolioRoute(),
        const MoreRoute(),
      ].every((r) => r.isTab),
      isTrue,
    );
    expect(
      [
        const StockRoute('X'),
        const StrategyRoute(),
        const SocketLabRoute(),
      ].any((r) => r.isTab),
      isFalse,
    );
  });

  test('fromUri maps every location back to its route', () {
    const ticket = OrderTicketRoute(
      OrderTicketArgs(
        instrumentId: 'NIFTY CE',
        side: OrderSide.sell,
        lots: 2,
        product: ProductType.mis,
        limitPrice: 125.5,
        source: OrderSource.ai,
      ),
    );
    for (final route in <AppRoute>[
      const WatchlistRoute(),
      const OptionChainRoute(underlying: 'BANKNIFTY'),
      const AiChatRoute(),
      const PortfolioRoute(section: PortfolioSection.holdings),
      const MoreRoute(),
      const AddFundsRoute(),
      const DebugClockRoute(),
      const AlertsRoute(),
      const SocketLabRoute(),
      const StockRoute('RELIANCE'),
      const StrategyRoute(),
      ticket,
    ]) {
      expect(AppRoute.fromUri(Uri.parse(route.location)), route);
    }
    expect(AppRoute.fromUri(Uri.parse('/')), const WatchlistRoute());
  });

  test('F14: unknown paths and bad query values', () {
    expect(AppRoute.fromUri(Uri.parse('/nope')), isNull);
    expect(AppRoute.fromUri(Uri.parse('/stock/')), isNull);
    expect(
      AppRoute.fromUri(Uri.parse('/portfolio?tab=x')),
      const PortfolioRoute(),
    );
    expect(
      AppRoute.fromUri(Uri.parse('/options?u=&e=2026-11-10&z=1')),
      const OptionChainRoute(expiry: '2026-11-10'),
    );
  });

  test('routes are values', () {
    expect(const StockRoute('A').hashCode, const StockRoute('A').hashCode);
    expect(const AddFundsRoute(), const AddFundsRoute());
    expect(const AddFundsRoute().hashCode, const AddFundsRoute().hashCode);
    expect(const AddFundsRoute() == const StrategyRoute(), isFalse);
    expect(const StockRoute('A') == const StockRoute('B'), isFalse);
    expect(
      const OptionChainRoute(underlying: 'A').hashCode,
      const OptionChainRoute(underlying: 'A').hashCode,
    );
    expect(
      const PortfolioRoute(section: PortfolioSection.orders).hashCode,
      const PortfolioRoute(section: PortfolioSection.orders).hashCode,
    );
    for (final r in <AppRoute>[
      const WatchlistRoute(),
      const AiChatRoute(),
      const MoreRoute(),
      const StrategyRoute(),
      const SocketLabRoute(),
    ]) {
      expect(r.hashCode, r.location.hashCode);
      expect(r == const StockRoute('X'), isFalse);
    }
  });
}
