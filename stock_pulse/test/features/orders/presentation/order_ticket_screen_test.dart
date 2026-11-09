import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/orders/di/order_preflight_provider.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';
import 'package:stock_pulse/features/orders/presentation/screens/order_ticket_screen.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

import '../../../helpers/fake_crash_reporter.dart';
import '../../../helpers/fake_local_prefs.dart';
import '../../../helpers/fake_market_repository.dart';
import '../../../helpers/fake_pending_order_store.dart';

class _Portfolio extends Mock implements PortfolioRepository {}

class _Orders extends Mock implements OrderRepository {}

const _option = Instrument(
  symbol: 'NIFTY25N24500CE',
  name: 'NIFTY 24500 CE',
  exchange: 'NFO',
  sector: '',
  tickSize: .05,
  lotSize: 75,
  kind: InstrumentKind.option,
);

final _quote = Quote(
  symbol: _option.symbol,
  ltp: 141.25,
  change: 1,
  changePercent: 1,
  lastTradeTime: DateTime.utc(2026, 11, 8, 5),
);

Order _placed(int quantity) => Order(
  id: 'o1',
  version: 1,
  symbol: _option.symbol,
  product: ProductType.nrml,
  side: OrderSide.buy,
  type: OrderType.market,
  quantity: quantity,
  status: OrderStatus.complete,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late _Portfolio portfolio;
  late _Orders orders;
  late FakeMarketRepository market;

  setUpAll(() {
    registerFallbackValue(OrderSide.buy);
    registerFallbackValue(OrderType.market);
    registerFallbackValue(ProductType.nrml);
    registerFallbackValue(
      const OrderRequest(
        symbol: 'NIFTY25N24500CE',
        side: OrderSide.buy,
        type: OrderType.market,
        product: ProductType.nrml,
        quantity: 75,
        lots: 1,
      ),
    );
  });

  setUp(() {
    portfolio = _Portfolio();
    orders = _Orders();
    market = FakeMarketRepository(instruments: [_option], quotes: [_quote]);
    when(
      () => orders.place(any(), idempotencyKey: any(named: 'idempotencyKey')),
    ).thenAnswer(
      (call) async => PlaceAcked(
        _placed(
          (call.positionalArguments.single as OrderRequest).quantity ?? 1,
        ),
      ),
    );
  });

  Widget ticket(OrderTicketArgs args, {bool riskNoticeAcked = true}) =>
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
          marketRepositoryProvider.overrideWithValue(market),
          marketClockProvider.overrideWith(
            (ref) => Stream.value(MarketClockState.fallback),
          ),
          networkStatusProvider.overrideWith(
            (ref) => Stream.value(NetworkStatus.live),
          ),
          freshnessTickProvider.overrideWith((ref) => const Stream.empty()),
          portfolioRepositoryProvider.overrideWithValue(portfolio),
          orderRepositoryProvider.overrideWithValue(orders),
          fakePendingOrderStoreOverride(),
          localPrefsProvider.overrideWith(
            (ref) async => FakeLocalPrefs(
              LocalPrefsData.defaults.copyWith(
                riskNoticeAcked: riskNoticeAcked,
              ),
            ),
          ),
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
          home: OrderTicketScreen(args: args),
        ),
      );

  testWidgets('option risk gate begins below the ticket app bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ticket(
        OrderTicketArgs(instrumentId: _option.symbol, side: OrderSide.buy),
        riskNoticeAcked: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Understand options risk'), findsOneWidget);
    expect(
      tester.getRect(find.text('Understand options risk')).top -
          tester.getRect(find.byType(AppBar).first).bottom,
      lessThan(60),
    );
  });

  testWidgets('prefilled lots from a position exit open as lots, not units', (
    tester,
  ) async {
    await tester.pumpWidget(
      ticket(
        OrderTicketArgs(
          instrumentId: _option.symbol,
          side: OrderSide.sell,
          lots: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Order · ${_option.symbol}'), findsOneWidget);
    expect(find.text('SELL 2 lots ${_option.symbol}'), findsOneWidget);
    expect(find.text('= 150 qty · ₹21,187.50'), findsOneWidget);
  });

  testWidgets('a missing contract shows Retry, which reloads it', (
    tester,
  ) async {
    await tester.pumpWidget(
      ticket(const OrderTicketArgs(instrumentId: 'GONE', side: OrderSide.buy)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(market.instrument('GONE'), isNull);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('stop loss checks the trigger against the limit for each side', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ticket(
        OrderTicketArgs(instrumentId: _option.symbol, side: OrderSide.buy),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Market'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop loss').last);
    await tester.pumpAndSettle();
    expect(
      find.text('The limit order is sent when the trigger price is reached.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Trigger price'),
      '150',
    );
    await tester.pump();
    expect(find.textContaining('A buy trigger must be'), findsOneWidget);
    await tester.tap(find.text('SELL').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('A buy trigger must be'), findsNothing);
    await tester.tap(find.byTooltip('Increase Lots'));
    await tester.pump();
    expect(find.text('SELL 2 lots ${_option.symbol}'), findsOneWidget);
    await tester.tap(find.byTooltip('Decrease Lots'));
    await tester.pump();
    expect(find.text('SELL 1 lot ${_option.symbol}'), findsOneWidget);
  });

  testWidgets('without a cached price the ticket loads one over REST', (
    tester,
  ) async {
    market = FakeMarketRepository(instruments: [_option]);
    await tester.pumpWidget(
      ticket(
        OrderTicketArgs(instrumentId: _option.symbol, side: OrderSide.buy),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('BUY 1 lot ${_option.symbol}'), findsOneWidget);
    expect(find.text('₹0.00'), findsWidgets);
  });

  testWidgets('the product picker switches an option to intraday', (
    tester,
  ) async {
    await tester.pumpWidget(
      ticket(
        OrderTicketArgs(instrumentId: _option.symbol, side: OrderSide.buy),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Carry forward'), findsOneWidget);
    await tester.tap(find.text('Carry forward'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intraday').last);
    await tester.pumpAndSettle();
    expect(find.text('Intraday'), findsOneWidget);
    expect(find.text('Carry forward'), findsNothing);
  });
}
