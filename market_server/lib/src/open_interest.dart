import 'dart:math';

import 'package:market_server/src/candle_math.dart';
import 'package:option_math/option_math.dart';

/// Simulated open interest per option contract, in units (lots × lot size).
///
/// Seeded at listing so OI peaks at the money, drifts while the market is
/// open and is measured against the day's opening value.
class OpenInterest {
  OpenInterest({Random? random}) : _random = random ?? Random();

  /// Chance that a contract's OI moves on one engine step.
  static const driftChance = 0.1;

  final Random _random;
  final _oi = <String, int>{};
  final _atOpen = <String, int>{};
  final _lots = <String, int>{};

  /// Lists [id] once; later calls keep the current value.
  void list(
    String id, {
    required int lot,
    required int strike,
    required double spot,
    required int step,
    required OptionRight right,
  }) {
    if (_oi.containsKey(id)) return;
    final distance = (strike - spot).abs();
    final inTheMoney = right == OptionRight.ce ? strike < spot : strike > spot;
    final decay = distance / (6 * step) * (inTheMoney ? 2 : 1);
    final seeded = lot * (4000 * exp(-decay)).round();
    _oi[id] = seeded;
    _atOpen[id] = seeded;
    _lots[id] = lot;
  }

  int oi(String id) => _oi[id] ?? 0;

  int change(String id) => oi(id) - (_atOpen[id] ?? 0);

  /// One engine step: each contract moves by `lot · round(N(0, 3))` with
  /// probability [driftChance], never below zero.
  void step() {
    for (final id in _oi.keys) {
      if (_random.nextDouble() >= driftChance) continue;
      final lots = (gaussian(_random) * 3).round();
      _oi[id] = max(0, _oi[id]! + lots * _lots[id]!);
    }
  }

  /// A new trading day: today's change starts from the current OI.
  void rollDay() => _atOpen.addAll(_oi);
}
