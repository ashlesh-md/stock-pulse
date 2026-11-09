import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:option_math/option_math.dart' show OptionRight;
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/options/di/options_data_providers.dart';
import 'package:stock_pulse/features/options/domain/chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';

import '../../../helpers/fake_market_repository.dart';
import '../../../helpers/fake_snapshot_store.dart';

const _id = 'NIFTY-261126-25000-CE';
const _instrument = Instrument(
  symbol: _id,
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

class _Feed implements ChainFeed {
  // Closed in tearDown.
  // ignore: close_sinks
  final views$ = StreamController<ChainView>.broadcast();
  @override
  Stream<ChainView> get views => views$.stream;
  @override
  void setVisibleRange(int fromStrike, int toStrike) {}
}

class _Chains implements ChainRepository {
  final feed = _Feed();
  ChainRequest? request;
  @override
  ChainFeed watchChain(ChainRequest req) {
    request = req;
    return feed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ChainView _view(DateTime asOf, {double? iv}) => ChainView(
  chainId: 'NIFTY:2026-11-26',
  seq: 1,
  asOf: asOf,
  spot: 25010,
  atm: 25000,
  status: ChainStatus.open,
  strikes: const [25000],
  rows: {
    25000: ChainRow(
      strike: 25000,
      ce: OptionCell(
        contractId: _id,
        ltp: 120,
        change: 1,
        oi: 10,
        oiChange: 0,
        iv: iv,
      ),
    ),
  },
);

void main() {
  late _Chains chains;
  late ProviderContainer container;
  setUp(() {
    chains = _Chains();
    container = ProviderContainer.test(
      overrides: [
        snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
        marketRepositoryProvider.overrideWithValue(
          FakeMarketRepository(instruments: const [_instrument]),
        ),
        chainRepositoryProvider.overrideWithValue(chains),
        screenVisibleProvider(ScreenId.strategy).overrideWithValue(true),
        marketClockProvider.overrideWith(
          (ref) => Stream.value(MarketClockState.fallback),
        ),
      ],
    );
    container.listen(strategyBuilderControllerProvider, (_, _) {});
    container
        .read(strategyDraftControllerProvider.notifier)
        .load(
          const StrategyArgs(
            legs: [
              StrategyLeg(
                contractId: _id,
                side: OrderSide.buy,
                lots: 1,
                premium: 120,
              ),
            ],
          ),
        );
  });
  tearDown(() => chains.feed.views$.close());

  test('a fresh chain view with IV draws the live today line', () async {
    await container.read(strategyBuilderControllerProvider.future);
    expect(chains.request?.fromStrike, 25000);
    chains.feed.views$.add(_view(DateTime.now().toUtc(), iv: 13.5));
    await pumpEventQueue();
    final state = container
        .read(strategyBuilderControllerProvider)
        .requireValue;
    expect(state.todayLive, isTrue);
    expect(state.legs.single.iv, closeTo(0.135, 1e-9));
  });

  test('a stale or IV-less view keeps the today line off', () async {
    await container.read(strategyBuilderControllerProvider.future);
    chains.feed.views$.add(_view(DateTime.utc(2020), iv: 13.5));
    await pumpEventQueue();
    expect(
      container.read(strategyBuilderControllerProvider).requireValue.todayLive,
      isFalse,
    );
    chains.feed.views$.add(_view(DateTime.now().toUtc()));
    await pumpEventQueue();
    final state = container
        .read(strategyBuilderControllerProvider)
        .requireValue;
    expect(state.todayLive, isFalse);
    expect(state.legs.single.iv, 0);
  });

  test('retry rebuilds from the draft', () async {
    await container.read(strategyBuilderControllerProvider.future);
    container.read(strategyBuilderControllerProvider.notifier).retry();
    final state = await container.read(
      strategyBuilderControllerProvider.future,
    );
    expect(state.legs, hasLength(1));
  });
}
