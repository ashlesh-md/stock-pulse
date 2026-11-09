import 'package:market_server/src/ai/answer_builder.dart';
import 'package:market_server/src/ai/answer_plan.dart';
import 'package:market_server/src/ai/ask_request.dart';
import 'package:option_math/option_math.dart';
import 'package:test/test.dart';

import 'fake_market_reads.dart';

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

  group('S2 plans: payoff and chain', () {
    test('payoff: summary equals option_math payoffSummary on the legs', () {
      final p = plan('payoff of a nifty straddle');
      expect(cards(p).map((c) => c['type']), ['payoff', 'text']);
      final body = p.cards.first.card['body']! as Map<String, Object?>;
      expect(body['underlying'], 'NIFTY');
      expect(body['lotSize'], 65);
      final legs = (body['legs']! as List).cast<Map<String, Object?>>();
      expect(legs.map((l) => '${l['side']} ${l['right']} ${l['strike']}'), [
        'buy CE 24500',
        'buy PE 24500',
      ]);
      final expected = payoffSummary([
        for (final l in legs)
          PayoffLeg(
            right: l['right'] == 'CE' ? OptionRight.ce : OptionRight.pe,
            strike: (l['strike']! as num).toDouble(),
            side: l['side'] == 'buy' ? LegSide.buy : LegSide.sell,
            units: (l['lots']! as int) * 65,
            premium: (l['premium']! as num).toDouble(),
            iv: (l['iv']! as num).toDouble(),
            expiryAt: FakeMarketReads.expiryAt,
          ),
      ]);
      expect(
        PayoffSummary.fromJson(
          (body['summary']! as Map<String, Object?>).cast(),
        ),
        expected,
      );
      expect(expected.maxProfit, isNull);
      final text = p.cards.last.textChunks.join();
      expect(text, startsWith('Long straddle: max loss ₹'));
      expect(text, contains('max profit Unlimited'));
      expect(p.chips, ['Explain Breakeven', 'NIFTY chain']);
      expect(
        p.topic,
        const AskContext(underlying: 'NIFTY', expiry: '2026-11-10'),
      );
      final actions = (p.cards.first.card['actions']! as List)
          .cast<Map<String, Object?>>();
      expect(actions.map((a) => a['kind']), ['view_payoff', 'trade']);
      final viewLegs =
          ((actions.first['args']! as Map<String, Object?>)['legs']! as List)
              .cast<Map<String, Object?>>();
      expect(viewLegs.first.keys, {'contractId', 'side', 'lots', 'premium'});
      expect(viewLegs.first['contractId'], 'NIFTY-261110-24500-CE');
      expect(actions.last['args'], {
        'instrumentId': 'NIFTY-261110-24500-CE',
        'side': 'buy',
        'lots': 1,
      });
    });

    test('payoff: the question strike is snapped; iron condor is 4 legs', () {
      final bull = plan('bull call spread nifty 24512');
      final legs =
          ((bull.cards.first.card['body']! as Map<String, Object?>)['legs']!
                  as List)
              .cast<Map<String, Object?>>();
      expect(legs.map((l) => l['strike']), [24500, 24600]);
      final condor = plan(
        'iron condor',
        ctx: const AskContext(underlying: 'NIFTY'),
      );
      final condorLegs =
          ((condor.cards.first.card['body']! as Map<String, Object?>)['legs']!
              as List);
      expect(condorLegs, hasLength(4));
      final s = PayoffSummary.fromJson(
        ((condor.cards.first.card['body']! as Map<String, Object?>)['summary']!
                as Map<String, Object?>)
            .cast(),
      );
      expect(s.maxProfit, isNotNull);
      expect(s.maxLoss, isNotNull);
    });

    test('payoff: an unlisted strike gives a text card with the range', () {
      final p = plan('long call nifty 30000');
      expect(cards(p).map((c) => c['type']), ['text']);
      expect(
        p.cards.single.textChunks.join(),
        '30,000 is not listed for 10 Nov; listed 23,500–25,500.',
      );
    });

    test('payoff and chain on an underlying without options → text card', () {
      for (final q in ['tcs straddle', 'tcs chain']) {
        final p = plan(q);
        expect(cards(p).map((c) => c['type']), ['text'], reason: q);
        expect(
          p.cards.single.textChunks.join(),
          'TCS has no listed options here.',
        );
      }
    });

    test('chain: quote, chain (ATM ± 2), text with PCR and max pain', () {
      final p = plan('What does the NIFTY chain say?');
      expect(cards(p).map((c) => c['type']), ['quote', 'chain', 'text']);
      final chain = p.cards[1].card;
      final body = chain['body']! as Map;
      final rows = (body['rows']! as List).cast<Map<String, Object?>>();
      expect(rows.map((r) => r['strike']), [24400, 24450, 24500, 24550, 24600]);
      expect(body['atm'], 24500);
      expect((rows.first['ce']! as Map<String, Object?>).keys, {
        'id',
        'ltp',
        'oi',
      });
      expect(chain['instruments'], hasLength(11));
      expect(
        p.cards[2].textChunks.join(),
        'PCR 0.92 (puts/calls by OI). Highest call OI at 24,700, '
        'highest put OI at 24,300. Max pain 24,500.',
      );
      final actions = (chain['actions']! as List).cast<Map<String, Object?>>();
      expect(actions.first, {
        'kind': 'open_chain',
        'label': 'Open chain',
        'args': {
          'underlying': 'NIFTY',
          'expiry': '2026-11-10',
          'strike': 24500,
        },
      });
      expect(
        (actions.last['args']! as Map<String, Object?>)['instrumentId'],
        'NIFTY-261110-24500-CE',
      );
      expect(p.chips, ['Payoff of a NIFTY straddle', 'Explain PCR']);
      expect(
        p.topic,
        const AskContext(underlying: 'NIFTY', expiry: '2026-11-10'),
      );
    });

    test('chain: ctx expiry is used only when it is listed', () {
      final ok = plan(
        'chain',
        ctx: const AskContext(underlying: 'NIFTY', expiry: '2026-11-10'),
      );
      expect(ok.topic.expiry, '2026-11-10');
      final bad = plan(
        'chain',
        ctx: const AskContext(underlying: 'NIFTY', expiry: '2020-01-01'),
      );
      expect(cards(bad).map((c) => c['type']), ['quote', 'chain', 'text']);
    });
  });
}
