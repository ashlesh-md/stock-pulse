import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/covered_state.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/market/presentation/screens/stock_detail_screen.dart';
import 'package:stock_pulse/features/more/presentation/screens/more_screen.dart';
import 'package:stock_pulse/features/more/presentation/screens/socket_lab_screen.dart';
import 'package:stock_pulse/features/options/presentation/screens/chain_screen.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart'
    show OrderSource;
import 'package:stock_pulse/features/orders/presentation/screens/order_ticket_screen.dart';
import 'package:stock_pulse/features/portfolio/presentation/screens/portfolio_screen.dart';
import 'package:stock_pulse/features/strategy/presentation/screens/strategy_builder_screen.dart';

import '../../helpers/fake_market_repository.dart';
import '../app_harness.dart';

void main() {
  late AppHarness h;
  setUp(() => h = AppHarness());

  bool visible(WidgetTester t, ScreenId id) =>
      h.container(t).read(screenVisibleProvider(id));
  BuildContext shellContext(WidgetTester t) =>
      t.element(find.byType(NavigationBar));

  testWidgets('T11 FR-82: unvisited tabs are not built on the first frame', (
    tester,
  ) async {
    await h.pumpPhone(tester);

    expect(find.byType(PortfolioScreen, skipOffstage: false), findsNothing);
    expect(find.byType(MoreScreen, skipOffstage: false), findsNothing);
    expect(visible(tester, ScreenId.watchlist), isTrue);
  });

  testWidgets('FR-86: a tab tap builds it, mirrors the tab and hides the '
      'last one', (tester) async {
    await h.pumpPhone(tester);

    await tester.tap(find.text('Portfolio'));
    await tester.pumpAndSettle();

    expect(find.byType(PortfolioScreen), findsOneWidget);
    expect(h.container(tester).read(selectedTabProvider), ScreenId.portfolio);
    expect(visible(tester, ScreenId.watchlist), isFalse);
    expect(visible(tester, ScreenId.portfolio), isTrue);
  });

  testWidgets('FR-110: Socket Lab opens from More, covers the shell and pops '
      'back to More', (tester) async {
    await h.pumpPhone(tester);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Socket Lab'));
    await tester.pumpAndSettle();
    expect(find.byType(SocketLabScreen), findsOneWidget);
    expect(visible(tester, ScreenId.more), isFalse);
    expect(
      h.container(tester).read(coveredStateProvider),
      const CoveredState(topOpaque: null, opaqueDepth: 1),
    );

    h.router(tester).pop();
    await tester.pumpAndSettle();
    expect(visible(tester, ScreenId.more), isTrue);
  });

  testWidgets('re-tapping the current tab returns it to its root', (
    tester,
  ) async {
    await h.pumpPhone(tester);
    final moreTab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('More'),
    );
    await tester.tap(moreTab);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Socket Lab'));
    await tester.pumpAndSettle();
    h.router(tester).pop();
    await tester.pumpAndSettle();

    await tester.tap(moreTab);
    await tester.pumpAndSettle();

    expect(h.router(tester).state.uri.path, MoreRoute.path);
    expect(h.container(tester).read(selectedTabProvider), ScreenId.more);
  });

  testWidgets('goTo a tab route selects that tab and builds its screen', (
    tester,
  ) async {
    await h.pumpPhone(tester);

    shellContext(tester).goTo(const OptionChainRoute(underlying: 'NIFTY'));
    await tester.pumpAndSettle();

    expect(find.byType(ChainScreen), findsOneWidget);
    expect(h.router(tester).state.uri.queryParameters['u'], 'NIFTY');
    expect(visible(tester, ScreenId.options), isTrue);

    shellContext(tester).goTo(const AiChatRoute());
    await tester.pumpAndSettle();
    expect(visible(tester, ScreenId.ai), isTrue);
  });

  testWidgets('D4: pushing a stock page over a stock page replaces it', (
    tester,
  ) async {
    await h.pumpPhone(tester);

    final ctx = shellContext(tester);
    ctx.pushTo<void>(const StockRoute('RELIANCE')).ignore();
    await tester.pumpAndSettle();
    tester
        .element(find.byType(StockDetailScreen))
        .pushTo<void>(const StockRoute('TCS'))
        .ignore();
    await tester.pumpAndSettle();

    expect(find.byType(StockDetailScreen), findsOneWidget);
    expect(
      h.container(tester).read(coveredStateProvider),
      const CoveredState(topOpaque: ScreenId.stockDetail, opaqueDepth: 1),
    );
    expect(h.router(tester).state.pathParameters['id'], 'TCS');
  });

  testWidgets('pushTo a tab route selects it instead of stacking', (
    tester,
  ) async {
    await h.pumpPhone(tester);
    shellContext(tester).pushTo<void>(const StrategyRoute()).ignore();
    await tester.pumpAndSettle();
    expect(find.byType(StrategyBuilderScreen), findsOneWidget);
    expect(visible(tester, ScreenId.strategy), isTrue);

    final result = await tester
        .element(find.byType(StrategyBuilderScreen))
        .pushTo<bool>(const MoreRoute());
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(MoreScreen), findsOneWidget);
    expect(visible(tester, ScreenId.strategy), isFalse);
    expect(h.container(tester).read(coveredStateProvider), CoveredState.shell);
  });

  testWidgets('F14: an unknown location and / land on the watchlist', (
    tester,
  ) async {
    await h.pumpPhone(tester);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    h.router(tester).go('/nope');
    await tester.pumpAndSettle();
    expect(h.router(tester).state.uri.path, WatchlistRoute.path);

    h.router(tester).go(PortfolioRoute.path);
    await tester.pumpAndSettle();
    h.router(tester).go('/');
    await tester.pumpAndSettle();
    expect(h.router(tester).state.uri.path, WatchlistRoute.path);
  });

  testWidgets('an in-app order URI builds the ticket from query arguments', (
    tester,
  ) async {
    await h.pumpPhone(tester);

    final router = h.router(tester);
    router.go('/order/RELIANCE?side=sell&lots=2&source=position');
    await tester.pumpAndSettle();

    expect(find.byType(OrderTicketScreen), findsOneWidget);
    expect(router.state.pathParameters['id'], 'RELIANCE');
    final args = tester
        .widget<OrderTicketScreen>(find.byType(OrderTicketScreen))
        .args;
    expect(args.side, OrderSide.sell);
    expect(args.lots, 2);
    expect(args.source, OrderSource.position);
  });

  testWidgets('custom deep links normalize to an allowed app route', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 11, 9, 9);
    h.marketRepository = FakeMarketRepository(
      instruments: const [
        Instrument(
          symbol: 'RELIANCE',
          name: 'Reliance Industries',
          exchange: 'NSE',
          sector: 'Energy',
          tickSize: 0.05,
          lotSize: 1,
        ),
      ],
      quotes: [
        Quote(
          symbol: 'RELIANCE',
          ltp: 1500,
          change: 0,
          changePercent: 0,
          lastTradeTime: now,
        ),
      ],
    );
    await h.pumpPhone(tester);

    final router = h.router(tester);
    router.go('stockpulse://app/stock/RELIANCE');
    await tester.pumpAndSettle();

    expect(find.byType(StockDetailScreen), findsOneWidget);
    expect(router.state.uri.path, '/stock/RELIANCE');

    router.go('https://evil.example/stock/TCS');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, WatchlistRoute.path);
    expect(find.text('Link not available'), findsOneWidget);

    router.go('stockpulse://app/trade/RELIANCE?side=buy&type=limit&price=1500');
    await tester.pumpAndSettle();
    expect(find.byType(OrderTicketScreen), findsOneWidget);
    final tradeArgs = tester
        .widget<OrderTicketScreen>(find.byType(OrderTicketScreen))
        .args;
    expect(tradeArgs.source, OrderSource.deeplink);
    expect(tradeArgs.side, OrderSide.buy);
    expect(tradeArgs.limitPrice, 1500);

    router.go('stockpulse://app/trade/RELIANCE?side=sell');
    await tester.pumpAndSettle();
    final sellArgs = tester
        .widget<OrderTicketScreen>(find.byType(OrderTicketScreen))
        .args;
    expect(sellArgs.source, OrderSource.deeplink);
    expect(sellArgs.side, OrderSide.sell);

    router.go('stockpulse://app/stock/XYZ');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, WatchlistRoute.path);
    expect(find.text('Link not available'), findsOneWidget);
  });
}
