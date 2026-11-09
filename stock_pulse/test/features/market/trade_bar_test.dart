import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/market/application/stock_detail_controller.dart';
import 'package:stock_pulse/features/market/application/stock_detail_state.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/market/presentation/widgets/trade_bar.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';

class _Detail extends StockDetailController {
  _Detail(this.kind) : super('X');
  final InstrumentKind kind;

  @override
  Future<StockDetailState> build() async => StockDetailState(
    instrument: Instrument(
      symbol: 'X',
      name: 'X',
      exchange: 'NSE',
      sector: '',
      tickSize: .05,
      lotSize: kind == InstrumentKind.option ? 75 : 1,
      kind: kind,
    ),
    quote: Quote(
      symbol: 'X',
      ltp: 100,
      change: 0,
      changePercent: 0,
      lastTradeTime: DateTime.utc(2026),
    ),
    range: ChartRange.d1,
    interval: ChartRange.d1.defaultInterval,
    candles: const [],
  );
}

void main() {
  late String? location;

  Future<void> pump(WidgetTester tester, InstrumentKind kind) async {
    location = null;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Consumer(
            builder: (_, ref, _) =>
                ref.watch(stockDetailControllerProvider('X')).hasValue
                ? const Scaffold(body: TradeBar(instrumentId: 'X'))
                : const SizedBox(),
          ),
        ),
        GoRoute(
          path: '/:rest(.*)',
          builder: (_, state) {
            location = state.uri.toString();
            return const Text('pushed');
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          stockDetailControllerProvider('X').overrideWith(() => _Detail(kind)),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an option opens the full-screen ticket', (tester) async {
    await pump(tester, InstrumentKind.option);
    await tester.tap(find.text('SELL'));
    await tester.pumpAndSettle();
    expect(
      location,
      const OrderTicketRoute(
        OrderTicketArgs(instrumentId: 'X', side: OrderSide.sell),
      ).location,
    );
  });

  testWidgets('an index shows one button to its option chain', (tester) async {
    await pump(tester, InstrumentKind.marketIndex);
    expect(find.text('BUY'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(location, startsWith('/options'));
  });
}
