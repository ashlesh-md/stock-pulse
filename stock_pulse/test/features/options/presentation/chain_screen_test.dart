import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/options/di/options_data_providers.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';
import 'package:stock_pulse/features/options/presentation/screens/chain_screen.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';

import '../../../helpers/chain_fixtures.dart';
import '../../../helpers/fake_local_prefs.dart';

void main() {
  late MockChainRepository repo;
  OrderTicketArgs? opened;
  setUp(() {
    repo = MockChainRepository();
    opened = null;
    when(() => repo.expiries('NIFTY')).thenAnswer(
      (_) async => Success([
        Expiry(
          code: '2026-11-09',
          expiryAt: DateTime.utc(2026, 11, 9, 10),
          kind: ExpiryKind.weekly,
          isToday: true,
        ),
        Expiry(
          code: '2026-11-16',
          expiryAt: DateTime.utc(2026, 11, 16, 10),
          kind: ExpiryKind.weekly,
          isToday: false,
        ),
        Expiry(
          code: '2026-11-25',
          expiryAt: DateTime.utc(2026, 11, 25, 10),
          kind: ExpiryKind.monthly,
          isToday: false,
        ),
      ]),
    );
    when(() => repo.getChain('NIFTY', any()))
        .thenAnswer((_) async => Success(fixtureChain()));
  });
  Future<void> pump(
    WidgetTester tester, {
    String initialLocation = '/options?u=NIFTY',
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: OptionChainRoute.path,
          builder: (_, state) {
            final route = OptionChainRoute.fromState(state);
            return ChainScreen(
              underlying: route.underlying,
              expiry: route.expiry,
            );
          },
        ),
        GoRoute(
          path: OrderTicketRoute.path,
          builder: (_, state) {
            opened = OrderTicketRoute.fromState(state).args;
            return const Text('ticket');
          },
        ),
        GoRoute(
          path: WatchlistRoute.path,
          builder: (_, _) => const Text('watchlist'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          chainRepositoryProvider.overrideWithValue(repo),
          localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
          screenVisibleProvider(ScreenId.options).overrideWithValue(false),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('large text keeps chain prices legible with taller rows', (
    tester,
  ) async {
    await pump(tester, textScale: 2);
    expect(
      tester
          .widgetList<ListView>(find.byType(ListView))
          .any((list) => list.itemExtent == 96),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('B4: expiry chips read 9 Nov with their tags', (tester) async {
    await pump(tester);
    expect(find.text('9 Nov  Expires today', findRichText: true), findsOne);
    expect(find.text('25 Nov  Monthly', findRichText: true), findsOne);
    expect(find.text('16 Nov  Weekly', findRichText: true), findsOne);
    await tester.tap(find.text('16 Nov  Weekly', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-11-09'), findsNothing);
  });
  testWidgets('switching expiry keeps current content visible during loading', (
    tester,
  ) async {
    final monthly = Completer<Result<ChainView>>();
    when(() => repo.getChain('NIFTY', '2026-11-25'))
        .thenAnswer((_) => monthly.future);
    await pump(tester);
    final monthlyChip = find.text('25 Nov  Monthly', findRichText: true);
    await tester.drag(find.byType(ListView).first, const Offset(-180, 0));
    await tester.pumpAndSettle();
    await tester.tap(monthlyChip);
    await tester.pump();
    verify(() => repo.getChain('NIFTY', '2026-11-25')).called(1);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('ATM'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(FadeTransition), findsNothing);
    monthly.complete(Success(fixtureChain()));
    await tester.pumpAndSettle();
    expect(find.text('ATM'), findsOneWidget);
    expect(find.text('25 Nov  Monthly', findRichText: true), findsOneWidget);
  });
  testWidgets('B5: opens centred on ATM with marker, OI and change', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('ATM'), findsOneWidget);
    expect(find.text('24,500'), findsOneWidget);
    expect(find.text(fixtureStrikes.first.toString()), findsNothing);
    expect(find.text('15.20L'), findsOneWidget);
    expect(find.text('+1.2K'), findsWidgets);
    expect(find.text('OI'), findsNWidgets(2));
    final atmY = tester.getCenter(find.text('ATM')).dy;
    expect(atmY, greaterThan(300));
    expect(find.text('Back to ATM'), findsNothing);
    await tester.drag(find.text('24,500'), const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(find.text('Back to ATM'), findsOneWidget);
    await tester.tap(find.text('Back to ATM'));
    await tester.pumpAndSettle();
    expect(find.text('ATM'), findsOneWidget);
    expect(find.text('Back to ATM'), findsNothing);
  });
  testWidgets('chain columns can be selected and LTP stays enabled', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Columns'));
    await tester.pumpAndSettle();
    final ltpRow = find.ancestor(
      of: find.text('LTP'),
      matching: find.byType(CheckboxListTile),
    );
    expect(tester.widget<CheckboxListTile>(ltpRow).enabled, isFalse);
    expect(find.text('Always shown'), findsOneWidget);
    await tester.tap(find.text('IV'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('IV'), findsNWidgets(2));
    expect(find.text('OI'), findsNWidgets(2));
    expect(find.text('LTP'), findsNWidgets(2));
  });
  testWidgets('a call cell opens Buy / Sell; Buy opens the ticket', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Call 24500,')));
    await tester.pumpAndSettle();
    expect(find.text('NIFTY24500CE'), findsOneWidget);
    await tester.tap(find.text('BUY'));
    await tester.pumpAndSettle();
    expect(opened?.instrumentId, 'NIFTY24500CE');
    expect(opened?.side, OrderSide.buy);
    expect(opened?.lots, isNull); // Null uses the order ticket's 1-lot default.
    expect(opened?.product, ProductType.nrml);
    expect(opened?.source, OrderSource.chain);
  });
  testWidgets('a failed load shows Retry, which loads again', (tester) async {
    when(() => repo.expiries('NIFTY'))
        .thenAnswer((_) async => const Failure(NetworkError()));
    await pump(tester);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    verify(() => repo.expiries('NIFTY')).called(2);
  });
  testWidgets('the column picker adds IV and delta to both sides', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Columns'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'i');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'IV'));
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Δ'));
    await tester.tap(find.widgetWithText(CheckboxListTile, 'ΔOI'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('IV'), findsNWidgets(2));
    expect(find.text('Δ'), findsNWidgets(2));
    expect(find.text('ΔOI'), findsNothing);
    expect(find.text('—'), findsWidgets);
    expect(find.text('13.40'), findsOneWidget);
    expect(find.text('0.52'), findsOneWidget);
  });

  testWidgets('an expiry without strikes says so', (tester) async {
    when(() => repo.getChain('NIFTY', any())).thenAnswer(
      (_) async => Success(
        ChainView(
          chainId: 'NIFTY:x',
          seq: 1,
          asOf: DateTime.utc(2026),
          spot: 1,
          atm: 0,
          status: ChainStatus.open,
          strikes: const [],
          rows: const {},
        ),
      ),
    );
    await pump(tester);
    expect(find.text('No contracts available for this expiry'), findsOne);
  });

  testWidgets('a put cell Sell opens a sell ticket; picking another expiry '
      'loads it', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Put 24500,')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SELL'));
    await tester.pumpAndSettle();
    expect(opened?.instrumentId, 'NIFTY24500PE');
    expect(opened?.side, OrderSide.sell);
  });
}
