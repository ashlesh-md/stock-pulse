import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/market/presentation/widgets/order_sheet.dart';
import 'package:stock_pulse/features/orders/di/order_preflight_provider.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/orders/domain/ticket_validation.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_funds_provider.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';

import '../../../helpers/fake_market_repository.dart';

void main() {
  testWidgets('soft warnings show together while the ticket remains usable', (
    tester,
  ) async {
    final market = FakeMarketRepository(
      instruments: [
        const Instrument(
          symbol: 'NIFTY-261109-25000-CE',
          name: 'NIFTY option',
          exchange: 'NFO',
          sector: 'Options',
          tickSize: .05,
          lotSize: 65,
          kind: InstrumentKind.option,
          underlying: 'NIFTY',
          expiry: '2026-11-09',
        ),
      ],
      quotes: [
        Quote(
          symbol: 'NIFTY',
          ltp: 25000,
          change: 0,
          changePercent: 0,
          lastTradeTime: DateTime.utc(2026, 11, 9, 10),
          fromCache: true,
        ),
      ],
    );
    const seed = (
      args: OrderTicketArgs(
        instrumentId: 'NIFTY-261109-25000-CE',
        side: OrderSide.sell,
        lots: 1,
        limitPrice: 130,
      ),
      lotSize: 65,
      tickSize: .05,
      ltp: 120.5,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketRepositoryProvider.overrideWithValue(market),
          portfolioFundsProvider.overrideWith(
            (ref) => Stream.value(const Funds(available: 5000, version: 1)),
          ),
          marketClockProvider.overrideWith(
            (ref) => Stream.value(
              MarketClockState.fallback.copyWith(
                phase: MarketPhase.open,
                tradingDay: '2026-11-09',
              ),
            ),
          ),
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(NetworkStatus.live),
          ),
          freshnessTickProvider.overrideWith((ref) => const Stream.empty()),
          orderPreflightProvider.overrideWithValue(
            ({
              required symbol,
              required side,
              required type,
              required product,
              required quantity,
              lots,
              limitPrice,
              triggerPrice,
            }) => null,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: OrderSheet(seed: seed)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('This limit price is more than 3% from the last price.'),
      findsOneWidget,
    );
    expect(
      find.text('This order is 169% of your available funds.'),
      findsOneWidget,
    );
    expect(find.text('This option expires today.'), findsOneWidget);
    expect(find.textContaining('underlying quote is delayed'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(
      find.text('Margin is not simulated for short options.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('option payoff preview opens strategy with one matching leg', (
    tester,
  ) async {
    final clocks = StreamController<MarketClockState>.broadcast(sync: true);
    addTearDown(clocks.close);
    TicketBlock? block = TicketBlock.preOpen;
    const seed = (
      args: OrderTicketArgs(
        instrumentId: 'NIFTY-261126-25000-CE',
        side: OrderSide.sell,
        lots: 2,
      ),
      lotSize: 25,
      tickSize: .05,
      ltp: 120.5,
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: OrderSheet(seed: seed)),
        ),
        GoRoute(
          path: '/strategy',
          builder: (_, _) => Consumer(
            builder: (context, ref, _) {
              final legs = ref.watch(strategyDraftControllerProvider).shownLegs;
              final leg = legs.single;
              return Scaffold(
                body: Text(
                  '${legs.length}:${leg.contractId}:${leg.side.name}:'
                  '${leg.lots}:${leg.premium}',
                ),
              );
            },
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
          marketClockProvider.overrideWith((ref) => clocks.stream),
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(NetworkStatus.live),
          ),
          freshnessTickProvider.overrideWith((ref) => const Stream.empty()),
          orderPreflightProvider.overrideWithValue(
            ({
              required symbol,
              required side,
              required type,
              required product,
              required quantity,
              lots,
              limitPrice,
              triggerPrice,
            }) => block,
          ),
          portfolioFundsProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    var confirm = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(confirm.onPressed, isNull);

    block = null;
    clocks.add(MarketClockState.fallback.copyWith(phase: MarketPhase.open));
    await tester.pumpAndSettle();
    confirm = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(confirm.onPressed, isNotNull);

    await tester.ensureVisible(find.text('Preview payoff'));
    await tester.tap(find.text('Preview payoff'));
    await tester.pumpAndSettle();

    expect(find.text('1:NIFTY-261126-25000-CE:sell:2:120.5'), findsOneWidget);
  });
}
