import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/options/di/options_data_providers.dart';
import 'package:stock_pulse/features/options/domain/chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';
import 'package:stock_pulse/features/options/presentation/screens/chain_screen.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_cell_sheet.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';

class _Repo extends Mock implements ChainRepository {}

void main() {
  testWidgets('long-pressing a strike opens call and put Greeks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _Repo();
    final strikes = [
      for (var index = -20; index <= 20; index++) 24500 + index * 50,
    ];
    final view = ChainView(
      chainId: 'NIFTY:2026-11-09',
      seq: 1,
      asOf: DateTime.utc(2026, 11, 8),
      spot: 24512.35,
      atm: 24500,
      status: ChainStatus.open,
      strikes: strikes,
      rows: {
        for (final strike in strikes)
          strike: ChainRow(
            strike: strike,
            ce: OptionCell(
              contractId:
                  'NIFTY$strike'
                  'CE',
              ltp: 100,
              change: 1,
              oi: 100,
              oiChange: 1,
              iv: 13.4,
            ),
            pe: OptionCell(
              contractId:
                  'NIFTY$strike'
                  'PE',
              ltp: 100,
              change: 1,
              oi: 100,
              oiChange: 1,
            ),
          ),
      },
    );
    when(() => repo.expiries('NIFTY')).thenAnswer(
      (_) async => Success([
        Expiry(
          code: '2026-11-09',
          expiryAt: DateTime.utc(2026, 11, 9, 10),
          kind: ExpiryKind.weekly,
          isToday: false,
        ),
      ]),
    );
    when(() => repo.getChain('NIFTY', any()))
        .thenAnswer((_) async => Success(view));

    final router = GoRouter(
      initialLocation: '/options?u=NIFTY',
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
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          chainRepositoryProvider.overrideWithValue(repo),
          screenVisibleProvider(ScreenId.options).overrideWithValue(false),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
          clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 11, 8))),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('24,500'));
    await tester.pumpAndSettle();
    expect(find.text('Option Greeks'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Put'), findsOneWidget);
    expect(find.textContaining('Gamma'), findsOneWidget);
    expect(find.textContaining('Theta / day'), findsOneWidget);
    expect(
      find.text('Greeks are unavailable for this contract.'),
      findsOneWidget,
    );
  });

  testWidgets('chain cell adds to the strategy draft from its sheet', (
    tester,
  ) async {
    final container = ProviderContainer.test();
    const cell = OptionCell(
      contractId: 'NIFTY-261109-24500-CE',
      ltp: 141.25,
      change: 1,
      oi: 100,
      oiChange: 0,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => showChainCellSheet(context, cell),
                child: const Text('Open cell'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open cell'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to strategy'));
    await tester.pumpAndSettle();

    final leg = container.read(strategyDraftControllerProvider).legs.single;
    expect(leg.contractId, cell.contractId);
    expect(leg.side, OrderSide.buy);
    expect(leg.premium, cell.ltp);
  });
}
