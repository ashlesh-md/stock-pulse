import 'package:option_math/option_math.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/strategy/application/payoff_geometry.dart';

class StrategyBuilderState {
  StrategyBuilderState({
    required this.instruments,
    required this.legs,
    required this.summary,
    required this.geometry,
    this.todayLive = false,
  });
  final List<Instrument> instruments;
  final List<PayoffLeg> legs;
  final PayoffSummary? summary;
  final PayoffGeometry? geometry;
  final bool todayLive;
}
