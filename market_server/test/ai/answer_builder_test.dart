import 'dart:convert';

import 'package:market_server/src/ai/answer_builder.dart';
import 'package:market_server/src/ai/answer_plan.dart';
import 'package:market_server/src/ai/ask_request.dart';
import 'package:market_server/src/ai/glossary.dart';
import 'package:market_server/src/ai/intent.dart';
import 'package:market_server/src/ai/strategy_templates.dart';
import 'package:market_server/src/market_calendar.dart';
import 'package:test/test.dart';

import 'fake_market_reads.dart';

const _questions = [
  'explain theta',
  'what is implied volatility',
  'payoff of a nifty straddle',
  'iron condor nifty',
  'bull call spread nifty 24500',
  'short put reliance',
  'What does the NIFTY chain say?',
  'pcr reliance',
  'compare reliance and hdfc bank',
  'tcs vs infy vs itc',
  'top movers today',
  'top losers',
  'quote reliance',
  'buy reliance',
  'nifty',
  'asdf',
];

const _forbidden = [
  'you should',
  'recommend',
  'buy now',
  'sell now',
  'guaranteed',
];

const _priceKeys = {'price', 'ltp', 'limitPrice', 'triggerPrice'};

void main() {
  late FakeMarketReads reads;
  late AnswerBuilder builder;

  setUp(() {
    reads = FakeMarketReads();
    builder = AnswerBuilder(reads);
  });

  AnswerPlan plan(String q, {AskContext? ctx}) =>
      builder.build(builder.parse(q, ctx), 'a7', ctx: ctx);

  Iterable<Map<String, Object?>> cards(AnswerPlan p) =>
      p.cards.map((c) => c.card);

  group('S2 every plan', () {
    for (final q in _questions) {
      test('"$q": ≤ 4 cards, ≤ 8 KB, envelope complete', () {
        final p = plan(q);
        expect(p.cards, isNotEmpty);
        expect(p.cards.length, lessThanOrEqualTo(4));
        final encoded = [
          for (final c in p.cards) ...[
            jsonEncode({'e': 'card', 'card': c.card}),
            for (final t in c.textChunks) jsonEncode({'e': 'delta', 'text': t}),
          ],
        ].join('\n');
        expect(utf8.encode(encoded).length, lessThanOrEqualTo(8 * 1024));
        var n = 0;
        for (final c in cards(p)) {
          n++;
          expect(c['id'], 'a7.c$n');
          expect(c['v'], 1);
          expect(c['type'], isA<String>());
          expect(c['title'], isA<String>());
          expect(c['asOf'], anyOf(isNull, isA<int>()));
          expect(c['instruments'], isA<List<Object?>>());
          final fb = c['fallbackText'];
          expect(fb, isA<String>());
          expect((fb! as String).length, inInclusiveRange(1, 300));
          expect(c['actions'], isA<List<Object?>>());
          expect(c['body'], isA<Map<String, Object?>>());
        }
      });
    }

    test('the same question and reads give the same cards', () {
      for (final q in _questions) {
        expect(
          jsonEncode(cards(plan(q)).toList()),
          jsonEncode(cards(plan(q)).toList()),
          reason: q,
        );
      }
    });
  });

  group('S2 plans per intent', () {
    test('explain: one text card, text only in chunks, chips re-parse', () {
      final p = plan('explain theta');
      expect(cards(p).map((c) => c['type']), ['text']);
      final body = p.cards.single.card['body']! as Map;
      expect(body['paragraphs'], isEmpty);
      expect(body['terms'], glossary['theta']!.related);
      final text = p.cards.single.textChunks.join();
      expect(text, contains('**Theta**'));
      expect(text, contains('\n\n'));
      expect(text, isNot(contains('Related:')));
      for (final chunk in p.cards.single.textChunks) {
        final words = chunk.trim().split(RegExp(r'\s+')).length;
        expect(words, inInclusiveRange(1, 6), reason: chunk);
      }
      expect(p.chips, hasLength(3));
      expect(builder.parse(p.chips[0], null), isA<ExplainIntent>());
      expect(builder.parse(p.chips[1], null), isA<ExplainIntent>());
      expect(p.chips[2], 'What does the NIFTY chain say?');
    });

    test('B13 explain follow-ups are chips only, never in-card links', () {
      final p = plan('explain theta');
      expect(p.cards.single.card['actions'], isEmpty);
      expect(p.chips, ['Explain Vega', 'Explain Expiry', starterChips.first]);
    });

    test('every glossary related chip re-parses to explain', () {
      for (final MapEntry(:key, :value) in glossary.entries) {
        for (final r in value.related) {
          expect(
            builder.parse('Explain ${glossary[r]!.title}', null),
            ExplainIntent(r),
            reason: '$key → $r',
          );
        }
      }
    });

    test('compare: one table of symbol, live LTP and change, with no text '
        'card repeating its summary', () {
      final p = plan('compare reliance and hdfc bank');
      expect(cards(p).map((c) => c['type']), ['table']);
      final body = p.cards.first.card['body']! as Map;
      final columns = (body['columns']! as List).cast<Map<String, Object?>>();
      expect(columns.map((c) => c['key']), ['symbol', 'ltp', 'changePct']);
      expect(columns.map((c) => c['live']), [false, true, true]);
      final rows = (body['rows']! as List).cast<Map<String, Object?>>();
      expect(rows.map((r) => r['id']), ['RELIANCE', 'HDFCBANK']);
      expect(
        p.cards.first.card['fallbackText'],
        'RELIANCE +1.20% · HDFCBANK −0.40%',
      );
      expect(p.chips, ['Quote RELIANCE', 'Top movers today']);
    });

    test('movers: one table of 5, chips flip', () {
      final gainers = plan('top movers today');
      expect(cards(gainers).map((c) => c['type']), ['table']);
      final rows =
          ((gainers.cards.single.card['body']! as Map<String, Object?>)['rows']!
              as List);
      expect(rows, hasLength(5));
      expect(gainers.chips, ['Top losers today']);
      expect(plan('top losers').chips, ['Top gainers today']);
    });

    test('quote: quote + 5m chart; trade words add the no-orders text', () {
      final p = plan('quote reliance');
      expect(cards(p).map((c) => c['type']), ['quote', 'chart']);
      final q = p.cards.first.card['body']! as Map;
      expect(q['phase'], 'open');
      expect(q['ltp'], 1412.35);
      final chart = p.cards[1].card['body']! as Map;
      expect(chart['interval'], '5m');
      expect((chart['points']! as List).length, lessThanOrEqualTo(75));
      expect(p.chips, ['RELIANCE chain', 'Compare RELIANCE and HDFCBANK']);
      expect(plan('quote tcs').chips, ['Compare TCS and RELIANCE']);

      final buy = plan('buy reliance');
      expect(cards(buy).map((c) => c['type']), ['quote', 'chart', 'text']);
      expect(
        buy.cards.last.textChunks.join(),
        "I can't place orders. Open the stock to trade.",
      );
    });

    test('quote phase comes from reads.phase()', () {
      reads.marketPhase = MarketPhase.preOpen;
      expect(
        (plan('tcs').cards.first.card['body']!
            as Map<String, Object?>)['phase'],
        'preOpen',
      );
    });

    test('unknown: fallback card with the 6 starter chips', () {
      final p = plan('asdf');
      expect(cards(p).map((c) => c['type']), ['fallback']);
      final body = p.cards.single.card['body']! as Map;
      expect(
        body['message'],
        'I can answer quotes, comparisons, chain summaries, payoffs, top movers and terms.',
      );
      expect(body['chips'], starterChips);
      expect(p.chips, starterChips);
      for (final chip in starterChips) {
        expect(
          builder.parse(chip, null),
          isNot(isA<UnknownIntent>()),
          reason: chip,
        );
      }
    });

    test('a missing read gives a fallback card, not an exception', () {
      reads.missing.add('RELIANCE');
      expect(cards(plan('quote reliance')).map((c) => c['type']), ['fallback']);
    });
  });

  group('S3 safety', () {
    test('no action has a price key or a place_order kind', () {
      for (final q in _questions) {
        for (final c in cards(plan(q))) {
          for (final a
              in (c['actions']! as List).cast<Map<String, Object?>>()) {
            expect(a['kind'], isNot('place_order'), reason: q);
            expect([
              'open_stock',
              'open_chart',
              'open_chain',
              'trade',
              'set_alert',
              'view_payoff',
              'explain',
            ], contains(a['kind']));
            final args = (a['args']! as Map<String, Object?>)
                .cast<String, Object?>();
            expect(
              args.keys.toSet().intersection(_priceKeys),
              isEmpty,
              reason: '$q $a',
            );
            for (final leg
                in (args['legs'] as List? ?? const [])
                    .cast<Map<String, Object?>>()) {
              expect(leg.keys.toSet().intersection(_priceKeys), isEmpty);
            }
          }
        }
      }
    });

    test('no template, glossary entry or answer uses advice phrases', () {
      final texts = <String>[
        for (final q in _questions)
          for (final c in plan(q).cards) ...[
            jsonEncode(c.card),
            c.textChunks.join(),
          ],
        for (final e in glossary.values) ...e.paragraphs,
        for (final k in StrategyKind.values) k.label,
        ...starterChips,
      ];
      for (final t in texts) {
        for (final f in _forbidden) {
          expect(t.toLowerCase(), isNot(contains(f)), reason: t);
        }
      }
    });
  });
}
