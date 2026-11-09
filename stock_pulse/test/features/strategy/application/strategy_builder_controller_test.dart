import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:option_math/option_math.dart' show OptionRight;
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/strategy/application/strategy_builder_state.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';

import '../../../helpers/fake_market_repository.dart';
import '../../../helpers/fake_snapshot_store.dart';

const _instrument = Instrument(
  symbol: 'NIFTY-261126-25000-CE',
  name: 'NIFTY 25000 CE',
  exchange: 'NFO',
  sector: 'Index options',
  tickSize: 0.05,
  lotSize: 25,
  kind: InstrumentKind.option,
  strikeStep: 50,
  underlying: 'NIFTY',
  expiry: '2026-11-26',
  strike: 25000,
  right: OptionRight.ce,
);

void main() {
  test('empty draft returns an empty payoff state', () async {
    final container = ProviderContainer.test(
      overrides: [
        snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
        marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
      ],
    );
    final keepAlive = container.listen(
      strategyBuilderControllerProvider,
      (_, _) {},
    );

    final state = await container.read(
      strategyBuilderControllerProvider.future,
    );

    expect(state.instruments, isEmpty);
    expect(state.legs, isEmpty);
    expect(state.summary, isNull);
    expect(state.geometry, isNull);
    keepAlive.close();
  });

  test('loads metadata and builds one payoff leg per draft leg', () async {
    final market = FakeMarketRepository(instruments: const [_instrument]);
    final container = ProviderContainer.test(
      overrides: [
        snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
        marketRepositoryProvider.overrideWithValue(market),
      ],
    );
    final keepAlive = container.listen(
      strategyBuilderControllerProvider,
      (_, _) {},
    );
    container
        .read(strategyDraftControllerProvider.notifier)
        .load(
          const StrategyArgs(
            legs: [
              StrategyLeg(
                contractId: 'NIFTY-261126-25000-CE',
                side: OrderSide.sell,
                lots: 2,
                premium: 130,
              ),
            ],
          ),
        );

    final state = await container.read(
      strategyBuilderControllerProvider.future,
    );

    expect(state.instruments, [_instrument]);
    expect(state.legs.single.units, 50);
    expect(state.legs.single.side.name, 'sell');
    expect(state.legs.single.strike, 25000);
    expect(state.summary, isNotNull);
    expect(state.geometry, isNotNull);
    expect(state.todayLive, isFalse);
    keepAlive.close();
  });

  test('missing instrument metadata is surfaced as a provider error', () async {
    final container = ProviderContainer.test(
      overrides: [
        snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
        marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
      ],
    );
    final error = Completer<AsyncValue<StrategyBuilderState>>();
    final keepAlive = container.listen(strategyBuilderControllerProvider, (
      _,
      next,
    ) {
      if (next.hasError && !error.isCompleted) {
        error.complete(next);
      }
    });
    container
        .read(strategyDraftControllerProvider.notifier)
        .load(
          const StrategyArgs(
            legs: [
              StrategyLeg(
                contractId: 'UNKNOWN-261126-25000-CE',
                side: OrderSide.buy,
                lots: 1,
                premium: 5,
              ),
            ],
          ),
        );

    final state = await error.future.timeout(const Duration(seconds: 2));
    expect(state.error, isA<ServerError>());
    keepAlive.close();
  });

  test(
    'builder loads without a chain subscription while strategy is hidden',
    () async {
      final market = FakeMarketRepository(instruments: const [_instrument]);
      final container = ProviderContainer.test(
        overrides: [
          snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
          marketRepositoryProvider.overrideWithValue(market),
        ],
      );
      final keepAlive = container.listen(
        strategyBuilderControllerProvider,
        (_, _) {},
      );
      container
          .read(strategyDraftControllerProvider.notifier)
          .load(
            const StrategyArgs(
              legs: [
                StrategyLeg(
                  contractId: 'NIFTY-261126-25000-CE',
                  side: OrderSide.buy,
                  lots: 1,
                  premium: 120,
                ),
              ],
            ),
          );
      container.read(selectedTabProvider.notifier).mirror(0);

      final state = await container.read(
        strategyBuilderControllerProvider.future,
      );

      expect(state.geometry, isNotNull);
      keepAlive.close();
    },
  );
}
