import 'package:flutter/material.dart';
import 'package:option_math/option_math.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/presentation/widgets/candle_chart.dart';
import 'package:stock_pulse/features/strategy/application/payoff_geometry.dart';
import 'package:stock_pulse/features/strategy/presentation/widgets/payoff_chart.dart';

class AiVisualContent extends StatelessWidget {
  const AiVisualContent({super.key, required this.card});
  final AiCard card;
  @override
  Widget build(BuildContext context) => switch (card.type) {
    'chart' => _chart(),
    'chain' => _chain(),
    'payoff' => _payoff(),
    _ => const SizedBox.shrink(),
  };
  Widget _chart() {
    final points = (card.body['points'] as List<Object?>? ?? const [])
        .cast<List<Object?>>();
    final candles = [
      for (final point in points)
        Candle(
          start: DateTime.fromMillisecondsSinceEpoch(
            point.first! as int,
            isUtc: true,
          ),
          open: (point[1]! as num).toDouble(),
          high: (point[1]! as num).toDouble(),
          low: (point[1]! as num).toDouble(),
          close: (point[1]! as num).toDouble(),
          volume: 0,
        ),
    ];
    return SizedBox(
      height: 180,
      child: CandleChart(
        candles: candles,
        interval: CandleInterval.m5,
        type: ChartType.line,
        baseline: (card.body['prevClose'] as num?)?.toDouble(),
      ),
    );
  }

  Widget _chain() {
    final rows = (card.body['rows'] as List<Object?>? ?? const [])
        .cast<Map<String, Object?>>();
    return Column(
      children: [
        for (final row in rows)
          Row(
            children: [
              Expanded(child: Text(_cell(row['ce']))),
              Expanded(
                child: Text(
                  row['strike'].toString(),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(child: Text(_cell(row['pe']), textAlign: TextAlign.end)),
            ],
          ),
      ],
    );
  }

  String _cell(Object? raw) => raw is Map<String, Object?> && raw['ltp'] is num
      ? Fmt.price((raw['ltp']! as num).toDouble())
      : '—';
  Widget _payoff() {
    final body = card.body;
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      body['expiryAt']! as int,
      isUtc: true,
    );
    final legs = [
      for (final raw in body['legs']! as List<Object?>)
        _leg(raw! as Map<String, Object?>, body['lotSize']! as int, expiry),
    ];
    if (legs.isEmpty || legs.length > 4) return const SizedBox.shrink();
    return PayoffChart(
      geometry: PayoffGeometry.build(
        legs,
        spot: (body['spot']! as num).toDouble(),
      ),
      summary: card.fallbackText,
      compact: true,
    );
  }

  PayoffLeg _leg(Map<String, Object?> leg, int lotSize, DateTime expiry) =>
      PayoffLeg(
        right: leg['right'] == 'CE' ? OptionRight.ce : OptionRight.pe,
        strike: (leg['strike']! as num).toDouble(),
        side: leg['side'] == 'sell' ? LegSide.sell : LegSide.buy,
        units: (leg['lots']! as int) * lotSize,
        premium: (leg['premium']! as num).toDouble(),
        iv: (leg['iv'] as num? ?? 0).toDouble(),
        expiryAt: expiry,
      );
}
