import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:option_math/option_math.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/options/di/options_data_providers.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/strategy/application/payoff_geometry.dart';
import 'package:stock_pulse/features/strategy/application/strategy_builder_state.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';

class StrategyBuilderController extends AsyncNotifier<StrategyBuilderState> {
  @override
  Future<StrategyBuilderState> build() async {
    final draft = ref.watch(strategyDraftControllerProvider).shownLegs;
    final visible = ref.watch(screenVisibleProvider(ScreenId.strategy));
    final repo = ref.watch(marketRepositoryProvider);
    if (draft.isEmpty) {
      return StrategyBuilderState(
        instruments: const [],
        legs: const [],
        summary: null,
        geometry: null,
      );
    }
    final metadata = await Future.wait([
      for (final leg in draft) repo.getInstrument(leg.contractId),
    ]);
    if (!ref.mounted) throw StateError('Strategy closed');
    final instruments = [for (final result in metadata) result.getOrThrow()];
    final legs = [
      for (var i = 0; i < draft.length; i++)
        PayoffLeg(
          right: instruments[i].right!,
          strike: instruments[i].strike!.toDouble(),
          side: draft[i].side == OrderSide.buy ? LegSide.buy : LegSide.sell,
          units: draft[i].lots * instruments[i].lotSize,
          premium: draft[i].premium,
          iv: 0,
          expiryAt: DateTime.parse('${instruments[i].expiry}T10:00:00Z'),
        ),
    ];
    if (visible) {
      final strikes = instruments.map((i) => i.strike!).toList();
      final feed = ref
          .watch(chainRepositoryProvider)
          .watchChain(
            ChainRequest(
              underlying: instruments.first.underlying!,
              expiry: instruments.first.expiry!,
              fromStrike: strikes.reduce(min),
              toStrike: strikes.reduce(max),
            ),
          );
      final sub = feed.views.listen((view) => _onView(view, instruments, legs));
      ref.onDispose(sub.cancel);
    }
    return StrategyBuilderState(
      instruments: List.unmodifiable(instruments),
      legs: List.unmodifiable(legs),
      summary: payoffSummary(legs),
      geometry: PayoffGeometry.build(legs),
    );
  }

  void _onView(
    ChainView view,
    List<Instrument> instruments,
    List<PayoffLeg> base,
  ) {
    if (!ref.mounted || !state.hasValue) return;
    final now = ref.read(serverClockProvider).now();
    var live = now.difference(view.asOf).inMilliseconds <= 5000;
    final legs = <PayoffLeg>[];
    for (var i = 0; i < base.length; i++) {
      final instrument = instruments[i];
      final row = view.rows[instrument.strike];
      final cell = instrument.right == OptionRight.ce ? row?.ce : row?.pe;
      if (cell?.iv == null ||
          now.difference(view.asOfFor(instrument.id)).inMilliseconds > 5000) {
        live = false;
      }
      legs.add(base[i].copyWith(iv: (cell?.iv ?? 0) / 100));
    }
    final market =
        ref.read(marketClockProvider).value ?? MarketClockState.fallback;
    state = AsyncData(
      StrategyBuilderState(
        instruments: instruments,
        legs: legs,
        summary: payoffSummary(legs),
        geometry: PayoffGeometry.build(
          legs,
          spot: view.spot,
          marketNow: live ? market.marketNow(now) : null,
        ),
        todayLive: live,
      ),
    );
  }

  void retry() => ref.invalidateSelf();
}
