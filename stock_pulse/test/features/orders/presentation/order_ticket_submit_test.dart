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
import 'package:stock_pulse/features/orders/presentation/widgets/order_sheet_header.dart';
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

  testWidgets(
    'C-8: a lot-size-75 option ticket opens at 1 lot and submits quantity 75',
    (tester) async {
      await tester.pumpWidget(
        ticket(
          OrderTicketArgs(instrumentId: _option.symbol, side: OrderSide.buy),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byType(OrderSheetHeader)).top -
            tester.getRect(find.byType(AppBar).first).bottom,
        lessThan(40),
      );
      final headerContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(OrderSheetHeader),
          matching: find.byType(Container),
        ),
      );
      expect((headerContainer.decoration! as BoxDecoration).border, isNull);
      expect(find.widgetWithText(TextField, 'Lots'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Lot size 75'), findsOneWidget);
      expect(find.text('= 75 qty · ₹10,593.75'), findsOneWidget);

      await tester.tap(find.text('BUY 1 lot ${_option.symbol}'));
      await tester.pumpAndSettle();

      final sent =
          verify(
                () => orders.place(
                  captureAny(),
                  idempotencyKey: any(named: 'idempotencyKey'),
                ),
              ).captured.single
              as OrderRequest;
      expect([sent.quantity, sent.lots], [75, 1]);
    },
  );
}
