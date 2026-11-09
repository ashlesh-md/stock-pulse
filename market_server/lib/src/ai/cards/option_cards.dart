import 'package:market_server/src/ai/cards/card_envelope.dart';
import 'package:market_server/src/ai/cards/card_format.dart';
import 'package:market_server/src/market_reads.dart';
import 'package:option_math/option_math.dart';

/// Chain snippet: the rows of [chain] (call with `around: 2`).
Map<String, Object?> chainCard({required String id, required ChainRead chain}) {
  final atmRow = chain.rows.firstWhere(
    (r) => r.strike == chain.atm,
    orElse: () => chain.rows[chain.rows.length ~/ 2],
  );
  Map<String, Object?> cell(ChainCellRead c) => {
    'id': c.id,
    'ltp': r2(c.ltp),
    'oi': c.oi,
  };
  return cardEnvelope(
    id: id,
    type: 'chain',
    title: '${chain.underlying} ${formatExpiry(chain.expiry)} chain',
    asOf: chain.asOf,
    instruments: [
      chain.underlying,
      for (final r in chain.rows) ...[r.ce.id, r.pe.id],
    ],
    fallbackText:
        '${chain.underlying} ${formatExpiry(chain.expiry)}: PCR '
        '${chain.pcr.toStringAsFixed(2)}, max pain ${formatInr(chain.maxPain)}, '
        'ATM ${formatInr(chain.atm)}',
    actions: [
      action('open_chain', 'Open chain', {
        'underlying': chain.underlying,
        'expiry': chain.expiry,
        'strike': chain.atm,
      }),
      action('trade', 'Trade this strike', {
        'instrumentId': atmRow.ce.id,
        'side': 'buy',
        'lots': 1,
      }),
    ],
    body: {
      'underlying': chain.underlying,
      'expiry': chain.expiry,
      'expiryAt': chain.expiryAt.millisecondsSinceEpoch,
      'spot': r2(chain.spot),
      'atm': chain.atm,
      'lotSize': chain.lotSize,
      'pcr': r2(chain.pcr),
      'maxPain': chain.maxPain,
      'maxCallOiStrike': chain.maxCallOiStrike,
      'maxPutOiStrike': chain.maxPutOiStrike,
      'rows': [
        for (final r in chain.rows)
          {'strike': r.strike, 'ce': cell(r.ce), 'pe': cell(r.pe)},
      ],
    },
  );
}

/// One priced payoff leg as the card carries it.
class CardLegJson {
  const CardLegJson({
    required this.id,
    required this.right,
    required this.strike,
    required this.side,
    required this.lots,
    required this.premium,
    required this.iv,
  });

  final String id;
  final OptionRight right;
  final int strike;
  final LegSide side;
  final int lots;
  final double premium;
  final double iv;
}

Map<String, Object?> payoffCard({
  required String id,
  required String title,
  required ChainRead chain,
  required List<CardLegJson> legs,
  required PayoffSummary summary,
  required String fallbackText,
}) => cardEnvelope(
  id: id,
  type: 'payoff',
  title: title,
  asOf: chain.asOf,
  instruments: [for (final l in legs) l.id],
  fallbackText: fallbackText,
  actions: [
    action('view_payoff', 'View payoff', {
      'legs': [
        for (final l in legs)
          {
            'contractId': l.id,
            'side': l.side.name,
            'lots': l.lots,
            'premium': r2(l.premium),
          },
      ],
    }),
    action('trade', 'Trade first leg', {
      'instrumentId': legs.first.id,
      'side': legs.first.side.name,
      'lots': 1,
    }),
  ],
  body: {
    'underlying': chain.underlying,
    'expiry': chain.expiry,
    'expiryAt': chain.expiryAt.millisecondsSinceEpoch,
    'spot': r2(chain.spot),
    'lotSize': chain.lotSize,
    'legs': [
      for (final l in legs)
        {
          'id': l.id,
          'right': l.right.name.toUpperCase(),
          'strike': l.strike,
          'side': l.side.name,
          'lots': l.lots,
          'premium': r2(l.premium),
          'iv': l.iv,
        },
    ],
    'summary': summary.toJson(),
  },
);

List<PayoffLeg> payoffLegsOf(List<CardLegJson> legs, ChainRead chain) => [
  for (final l in legs)
    PayoffLeg(
      right: l.right,
      strike: l.strike.toDouble(),
      side: l.side,
      units: l.lots * chain.lotSize,
      premium: l.premium,
      iv: l.iv,
      expiryAt: chain.expiryAt,
    ),
];

/// "Straddle: max loss ₹X, max profit Unlimited, breakevens A and B."
String payoffLine(String strategy, PayoffSummary summary) {
  final loss = summary.maxLoss == null
      ? 'Unlimited'
      : '₹${formatInr(summary.maxLoss!.abs())}';
  final profit = summary.maxProfit == null
      ? 'Unlimited'
      : '₹${formatInr(summary.maxProfit!)}';
  final bes = summary.breakevens.isEmpty
      ? 'none'
      : summary.breakevens.map(formatInr).join(' and ');
  return '$strategy: max loss $loss, max profit $profit, breakevens $bes.';
}
