import 'package:market_server/src/ai/answer_builder.dart';
import 'package:market_server/src/ai/answer_stream.dart';
import 'package:market_server/src/ai/ask_request.dart';
import 'package:market_server/src/ai/cards/card_format.dart';
import 'package:market_server/src/ai/cards/option_cards.dart';
import 'package:market_server/src/ai/cards/quote_cards.dart';
import 'package:market_server/src/ai/cards/text_cards.dart';
import 'package:market_server/src/ai/intent.dart';
import 'package:market_server/src/ai/strategy_templates.dart';
import 'package:market_server/src/market_reads.dart';
import 'package:market_server/src/models.dart';
import 'package:test/test.dart';

import 'fake_market_reads.dart';

void main() {
  group('AskContext', () {
    test('toJson drops null fields; copyWith keeps unset ones', () {
      const ctx = AskContext(underlying: 'NIFTY');
      expect(ctx.toJson(), {'underlying': 'NIFTY'});
      final next = ctx.copyWith(expiry: '2026-11-10');
      expect(next, const AskContext(underlying: 'NIFTY', expiry: '2026-11-10'));
      expect(next.copyWith(), next);
      expect(next.hashCode, next.copyWith().hashCode);
      expect(next.toString(), 'AskContext(NIFTY, 2026-11-10)');
    });
  });

  test(
    'intents with equal fields share a hash code and print their fields',
    () {
      final pairs = <(Intent, String)>[
        (const ExplainIntent('theta'), 'ExplainIntent(theta)'),
        (
          const PayoffIntent(StrategyKind.straddle, 'NIFTY', null),
          'PayoffIntent(straddle, NIFTY, null)',
        ),
        (const ChainIntent('NIFTY'), 'ChainIntent(NIFTY)'),
        (const CompareIntent(['TCS', 'INFY']), 'CompareIntent([TCS, INFY])'),
        (
          const MoversIntent(losers: true, gainersOnly: false),
          'MoversIntent(losers: true, gainers: false)',
        ),
        (
          const QuoteIntent('TCS', tradeWords: true),
          'QuoteIntent(TCS, tradeWords: true)',
        ),
        (const UnknownIntent(), 'UnknownIntent()'),
      ];
      for (final (intent, text) in pairs) {
        expect(intent.hashCode, isA<int>());
        expect(intent.toString(), text);
      }
      expect(
        const CompareIntent(['TCS']).hashCode,
        const CompareIntent(['TCS']).hashCode,
      );
    },
  );

  group('cards', () {
    test('formatInr groups Indian style and marks negatives', () {
      expect(formatInr(123456.5), '1,23,456.50');
      expect(formatInr(-1412.35), '−1,412.35');
      expect(formatInr(950), '950');
    });

    test('a fallback text over 300 characters is cut with an ellipsis', () {
      final card = textCard(
        id: 'a1.c1',
        title: 'Long',
        asOf: DateTime.utc(2026, 11, 7),
        fallbackText: 'x' * 400,
      );
      final text = card['fallbackText']! as String;
      expect(text, hasLength(300));
      expect(text, endsWith('…'));
    });

    test('a chart card keeps the newest 75 points', () {
      final start = DateTime.utc(2026, 11, 7, 3, 45);
      final candles = [
        for (var i = 0; i < 80; i++)
          Candle(
            start: start.add(Duration(minutes: 5 * i)),
            open: 1,
            high: 1,
            low: 1,
            close: i.toDouble(),
            volume: 0,
          ),
      ];
      final card = chartCard(
        id: 'a1.c2',
        instrumentId: 'TCS',
        prevClose: 1,
        candles: candles,
        asOf: start,
      );
      final points = (card['body']! as Map)['points'] as List;
      expect(points, hasLength(75));
      expect((points.first as List).last, 5.0);
    });

    test('a chain without its ATM row marks the middle row', () {
      final chain = FakeMarketReads().chainSnapshot('NIFTY')!;
      final shifted = ChainRead(
        underlying: chain.underlying,
        expiry: chain.expiry,
        expiryAt: chain.expiryAt,
        asOf: chain.asOf,
        spot: chain.spot,
        pcr: chain.pcr,
        atm: chain.atm + 1,
        strikeStep: chain.strikeStep,
        lotSize: chain.lotSize,
        maxPain: chain.maxPain,
        maxCallOiStrike: chain.maxCallOiStrike,
        maxPutOiStrike: chain.maxPutOiStrike,
        rows: chain.rows,
      );
      final card = chainCard(id: 'a1.c2', chain: shifted);
      final trade = (card['actions']! as List)
          .cast<Map<String, Object?>>()
          .last;
      final middle = chain.rows[chain.rows.length ~/ 2];
      expect((trade['args']! as Map)['instrumentId'], middle.ce.id);
    });
  });

  group('AnswerBuilder edge cases', () {
    test('explain on a term outside the glossary gives the fallback', () {
      final plan = AnswerBuilder(
        FakeMarketReads(),
      ).build(const ExplainIntent('nope'), 'a1');
      expect(plan.cards.single.card['type'], 'fallback');
    });

    test('a payoff anchored on an unlisted strike names the listed range', () {
      final plan = AnswerBuilder(
        FakeMarketReads(),
      ).build(const PayoffIntent(StrategyKind.longCall, 'NIFTY', 99999), 'a1');
      expect(plan.cards.single.card['type'], 'text');
      expect(plan.cards.single.textChunks.join(), contains('not listed'));
    });

    test(
      'a listed anchor with a wing off the chain names the listed range',
      () {
        final reads = FakeMarketReads();
        final last = reads.chainSnapshot('NIFTY', around: 20)!.rows.last.strike;
        final plan = AnswerBuilder(
          reads,
        ).build(PayoffIntent(StrategyKind.ironCondor, 'NIFTY', last), 'a1');
        expect(plan.cards.single.textChunks.join(), contains('not listed'));
      },
    );
  });

  test('AnswerStream runs on the real clock by default', () {
    expect(AnswerStream(builder: AnswerBuilder(FakeMarketReads())).active, 0);
  });
}
