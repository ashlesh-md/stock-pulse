import 'package:market_server/src/ai/ask_request.dart';
import 'package:market_server/src/ai/glossary.dart';
import 'package:market_server/src/ai/intent.dart';
import 'package:market_server/src/ai/intent_parser.dart';
import 'package:market_server/src/ai/strategy_templates.dart';
import 'package:market_server/src/models.dart';
import 'package:option_math/option_math.dart';
import 'package:test/test.dart';

// One place to build instruments, so a change to the Instrument
// constructor (dev-realtime S-6) is a one-line fix here.
Instrument _inst(String symbol, String name) => Instrument(
  symbol: symbol,
  name: name,
  exchange: 'NSE',
  sector: 'Test',
  basePrice: 100,
);

final _instruments = [
  _inst('NIFTY', 'Nifty 50'),
  _inst('RELIANCE', 'Reliance Industries'),
  _inst('HDFCBANK', 'HDFC Bank'),
  _inst('HDFCLIFE', 'HDFC Life'),
  _inst('TCS', 'Tata Consultancy Services'),
  _inst('INFY', 'Infosys'),
  _inst('WIPRO', 'Wipro'),
  _inst('ITC', 'ITC'),
  _inst('SBIN', 'State Bank of India'),
];

void main() {
  final parser = IntentParser(_instruments, aliases: {'hdfc': 'HDFCLIFE'});
  const nifty = AskContext(underlying: 'NIFTY');
  const reliance = AskContext(underlying: 'RELIANCE');

  // (question, context, expected intent)
  final cases = <(String, AskContext?, Intent)>[
    // R1 explain
    ('explain theta', null, const ExplainIntent('theta')),
    ('What is implied volatility?', null, const ExplainIntent('iv')),
    ("what's a straddle", null, const ExplainIntent('straddle')),
    ('what does PCR mean', null, const ExplainIntent('pcr')),
    ('define open interest', null, const ExplainIntent('oi')),
    ('meaning of max pain', null, const ExplainIntent('max pain')),
    // R1 falls through when the rest is not a glossary term
    (
      'what is reliance',
      null,
      const QuoteIntent('RELIANCE', tradeWords: false),
    ),
    // R2 payoff
    (
      'payoff of a nifty straddle',
      null,
      const PayoffIntent(StrategyKind.straddle, 'NIFTY', null),
    ),
    (
      'bull call spread nifty 24500',
      null,
      const PayoffIntent(StrategyKind.bullCallSpread, 'NIFTY', 24500),
    ),
    (
      'iron condor',
      nifty,
      const PayoffIntent(StrategyKind.ironCondor, 'NIFTY', null),
    ),
    (
      'iron condor',
      reliance,
      const PayoffIntent(StrategyKind.ironCondor, 'RELIANCE', null),
    ),
    (
      'short straddle p&l',
      null,
      const PayoffIntent(StrategyKind.shortStraddle, 'NIFTY', null),
    ),
    (
      'long put reliance 1400',
      null,
      const PayoffIntent(StrategyKind.longPut, 'RELIANCE', 1400),
    ),
    (
      'short strangle nifty 50',
      null,
      const PayoffIntent(StrategyKind.shortStrangle, 'NIFTY', null),
    ),
    (
      'bear put spread on hdfc bank',
      null,
      const PayoffIntent(StrategyKind.bearPutSpread, 'HDFCBANK', null),
    ),
    // R3 chain
    ('What does the NIFTY chain say?', null, const ChainIntent('NIFTY')),
    ('pcr reliance', null, const ChainIntent('RELIANCE')),
    ('option chain of hdfc bank', null, const ChainIntent('HDFCBANK')),
    ('max pain nifty', null, const ChainIntent('NIFTY')),
    ('chain', reliance, const ChainIntent('RELIANCE')),
    // R4 compare
    (
      'compare reliance and hdfc bank',
      null,
      const CompareIntent(['RELIANCE', 'HDFCBANK']),
    ),
    (
      'tcs vs infy vs wipro',
      null,
      const CompareIntent(['TCS', 'INFY', 'WIPRO']),
    ),
    ('compare reliance & tcs', null, const CompareIntent(['RELIANCE', 'TCS'])),
    (
      'compare tcs, infy, wipro, itc, sbin, reliance',
      null,
      const CompareIntent(['TCS', 'INFY', 'WIPRO', 'ITC', 'SBIN']),
    ),
    // R5 movers
    (
      'top movers today',
      null,
      const MoversIntent(losers: false, gainersOnly: false),
    ),
    ('Top losers', null, const MoversIntent(losers: true, gainersOnly: false)),
    (
      'biggest gainers',
      null,
      const MoversIntent(losers: false, gainersOnly: true),
    ),
    (
      'who is down most',
      null,
      const MoversIntent(losers: true, gainersOnly: false),
    ),
    // R6 quote
    ('quote reliance', null, const QuoteIntent('RELIANCE', tradeWords: false)),
    ('tcs', null, const QuoteIntent('TCS', tradeWords: false)),
    (
      'how is infosys doing',
      null,
      const QuoteIntent('INFY', tradeWords: false),
    ),
    ('price of ril', null, const QuoteIntent('RELIANCE', tradeWords: false)),
    ('buy reliance', null, const QuoteIntent('RELIANCE', tradeWords: true)),
    ('sell 10 tcs now', null, const QuoteIntent('TCS', tradeWords: true)),
    // Longest phrase wins: "hdfc bank" beats the "hdfc" alias.
    ('quote hdfc bank', null, const QuoteIntent('HDFCBANK', tradeWords: false)),
    ('quote hdfc', null, const QuoteIntent('HDFCLIFE', tradeWords: false)),
    // R7 fallback
    ('asdf', null, const UnknownIntent()),
    ('tell me a joke', null, const UnknownIntent()),
    ('pcr', null, const UnknownIntent()),
    ('', null, const UnknownIntent()),
  ];

  for (final (question, ctx, expected) in cases) {
    test(
      '"$question"${ctx == null ? '' : ' + ctx ${ctx.underlying}'} → $expected',
      () {
        expect(parser.parse(question, ctx), expected);
      },
    );
  }

  test('every intent has a wire name', () {
    expect(const ExplainIntent('iv').name, 'explain');
    expect(
      const PayoffIntent(StrategyKind.straddle, 'NIFTY', null).name,
      'payoff',
    );
    expect(const ChainIntent('NIFTY').name, 'chain');
    expect(const CompareIntent(['A', 'B']).name, 'compare');
    expect(
      const MoversIntent(losers: false, gainersOnly: false).name,
      'movers',
    );
    expect(const QuoteIntent('TCS', tradeWords: false).name, 'quote');
    expect(const UnknownIntent().name, 'unknown');
  });

  group('strategy templates', () {
    test('strikes snap to the nearest step (ties go down)', () {
      expect(snapStrike(24512, 50), 24500);
      expect(snapStrike(24530, 50), 24550);
      expect(snapStrike(24525, 50), 24500);
      expect(snapStrike(1403, 10), 1400);
    });

    test('legs are relative to the anchor, 1 lot each', () {
      String fmt(LegTemplate l) => '${l.side.name} ${l.right.name} ${l.strike}';
      expect(legsFor(StrategyKind.longCall, 24500, 50).map(fmt), [
        'buy ce 24500',
      ]);
      expect(legsFor(StrategyKind.shortPut, 24500, 50).map(fmt), [
        'sell pe 24500',
      ]);
      expect(legsFor(StrategyKind.straddle, 24500, 50).map(fmt), [
        'buy ce 24500',
        'buy pe 24500',
      ]);
      expect(legsFor(StrategyKind.strangle, 24500, 50).map(fmt), [
        'buy ce 24600',
        'buy pe 24400',
      ]);
      expect(legsFor(StrategyKind.bullCallSpread, 24500, 50).map(fmt), [
        'buy ce 24500',
        'sell ce 24600',
      ]);
      expect(legsFor(StrategyKind.bearPutSpread, 24500, 50).map(fmt), [
        'buy pe 24500',
        'sell pe 24400',
      ]);
      expect(legsFor(StrategyKind.ironCondor, 24500, 50).map(fmt), [
        'sell pe 24400',
        'buy pe 24300',
        'sell ce 24600',
        'buy ce 24700',
      ]);
      for (final kind in StrategyKind.values) {
        final legs = legsFor(kind, 24500, 50);
        expect(legs.length, inInclusiveRange(1, 4));
        expect(legs.every((l) => l.lots == 1), isTrue);
        expect(legs.first.side, isA<LegSide>());
        expect(legs.first.right, isA<OptionRight>());
      }
    });
  });

  group('glossary', () {
    test('has about 20 terms with related keys that exist', () {
      expect(glossary.length, inInclusiveRange(18, 26));
      for (final MapEntry(:key, :value) in glossary.entries) {
        expect(value.paragraphs, isNotEmpty, reason: key);
        for (final r in value.related) {
          expect(glossary.containsKey(r), isTrue, reason: '$key → $r');
        }
      }
    });

    test('lookup finds keys and synonyms', () {
      expect(lookupTerm('implied volatility'), 'iv');
      expect(lookupTerm('open interest'), 'oi');
      expect(lookupTerm('theta'), 'theta');
      expect(lookupTerm('reliance'), isNull);
    });
  });

  group('AskRequest.fromJson', () {
    test('trims and reads the context', () {
      final r = AskRequest.fromJson({
        'question': '  explain iv  ',
        'requestId': 'r1',
        'context': {'underlying': 'NIFTY', 'expiry': '2026-11-10'},
      });
      expect(r.question, 'explain iv');
      expect(r.requestId, 'r1');
      expect(
        r.context,
        const AskContext(underlying: 'NIFTY', expiry: '2026-11-10'),
      );
    });

    test('rejects bad bodies with FormatException', () {
      for (final body in <Object?>[
        null,
        'text',
        {'question': '   ', 'requestId': 'r1'},
        {'question': 'x' * 201, 'requestId': 'r1'},
        {'question': 'hi'},
        {'question': 'hi', 'requestId': ''},
        {'question': 'hi', 'requestId': 'x' * 65},
        {'question': 'hi', 'requestId': 'r1', 'context': 'NIFTY'},
        {
          'question': 'hi',
          'requestId': 'r1',
          'context': {'underlying': 5},
        },
      ]) {
        expect(
          () => AskRequest.fromJson(body),
          throwsFormatException,
          reason: '$body',
        );
      }
    });
  });
}
