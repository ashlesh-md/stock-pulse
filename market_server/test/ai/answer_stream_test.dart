import 'dart:async';

import 'package:market_server/src/ai/answer_builder.dart';
import 'package:market_server/src/ai/answer_stream.dart';
import 'package:market_server/src/ai/ask_request.dart';
import 'package:market_server/src/market_clock.dart';
import 'package:test/test.dart';

import 'fake_market_reads.dart';

void main() {
  late FakeMarketReads reads;
  late FakeMarketClock clock;
  late AnswerStream stream;

  setUp(() {
    reads = FakeMarketReads();
    clock = FakeMarketClock(wallStart: reads.wall);
    stream = AnswerStream(builder: AnswerBuilder(reads), clock: clock);
  });

  AskRequest ask(String q, {AskContext? ctx}) =>
      AskRequest(question: q, requestId: 'r1', context: ctx);

  /// Runs [events] to the end, advancing the fake clock between turns.
  Future<List<Map<String, Object?>>> drain(
    Stream<Map<String, Object?>> events,
  ) async {
    final out = <Map<String, Object?>>[];
    var finished = false;
    events.listen(out.add, onDone: () => finished = true);
    for (var i = 0; i < 1000 && !finished; i++) {
      await Future<void>.delayed(Duration.zero);
      clock.advance(const Duration(milliseconds: 50));
    }
    expect(finished, isTrue, reason: 'stream did not finish');
    return out;
  }

  test('nothing is sent before the think delay', () async {
    final out = <Object?>[];
    stream.run(ask('quote reliance')).listen(out.add);
    await Future<void>.delayed(Duration.zero);
    clock.advance(const Duration(milliseconds: 299));
    await Future<void>.delayed(Duration.zero);
    expect(out, isEmpty);
    expect(stream.active, 1);
    clock.advance(const Duration(milliseconds: 401));
    await Future<void>.delayed(Duration.zero);
    expect(out, hasLength(2)); // start, then card 1 with no wait
  });

  test('start, cards, deltas that rebuild the text, done', () async {
    final events = await drain(stream.run(ask('payoff of a nifty straddle')));
    expect(events.first['e'], 'start');
    expect(events.first['intent'], 'payoff');
    expect(events.first['serverTime'], reads.wall.millisecondsSinceEpoch);
    final answerId = events.first['answerId'];
    final kinds = [for (final e in events) e['e']];
    expect(kinds.first, 'start');
    expect(kinds.last, 'done');
    expect(kinds.where((k) => k == 'card'), hasLength(2));
    final textCard = events
        .where((e) => e['e'] == 'card')
        .map((e) => e['card']! as Map)
        .last;
    expect(textCard['id'], '$answerId.c2');
    final text = events
        .where((e) => e['e'] == 'delta' && e['cardId'] == textCard['id'])
        .map((e) => e['text'])
        .join();
    expect(text, startsWith('Long straddle: max loss'));
    final done = events.last;
    expect(done['cards'], 2);
    expect(done['topic'], {'underlying': 'NIFTY', 'expiry': '2026-11-10'});
    expect(done['chips'], ['Explain Breakeven', 'NIFTY chain']);
    expect(stream.active, 0);
  });

  test('the context carries into a follow-up', () async {
    final events = await drain(
      stream.run(ask('chain', ctx: const AskContext(underlying: 'RELIANCE'))),
    );
    expect(events.first['intent'], 'chain');
    expect((events.last['topic']! as Map)['underlying'], 'RELIANCE');
  });

  test('a failing read before the first card gives error internal', () async {
    reads.throwOnRead = StateError('boom');
    final events = await drain(stream.run(ask('quote reliance')));
    expect([for (final e in events) e['e']], ['start', 'error']);
    expect(events.last['code'], 'internal');
    expect(events.last['retryable'], true);
    expect(stream.active, 0);
  });

  test('debug fault after card N: start, N cards, error', () async {
    final events = await drain(
      stream.run(ask('What does the NIFTY chain say?'), debugErrorAfterCard: 2),
    );
    expect(
      [for (final e in events) e['e']],
      ['start', 'card', 'card', 'error'],
    );
    expect(events.last['code'], 'debug_fault');
  });

  test('cancel stops at the next yield and active drops', () async {
    final got = <Map<String, Object?>>[];
    final sub = stream
        .run(ask('What does the NIFTY chain say?'))
        .listen(got.add);
    await Future<void>.delayed(Duration.zero);
    clock.advance(const Duration(milliseconds: 700));
    await Future<void>.delayed(Duration.zero);
    expect(got.map((e) => e['e']), ['start', 'card']);
    final cancelled = sub.cancel();
    clock.advance(const Duration(milliseconds: 150));
    await cancelled;
    expect(stream.active, 0);
    expect(got, hasLength(2));
  });

  test('the same question waits the same think time', () async {
    Future<int> thinkMs() async {
      final c = FakeMarketClock(wallStart: reads.wall);
      final s = AnswerStream(builder: AnswerBuilder(reads), clock: c);
      var started = false;
      s.run(ask('quote tcs')).listen((_) => started = true);
      var ms = 0;
      while (!started) {
        await Future<void>.delayed(Duration.zero);
        c.advance(const Duration(milliseconds: 10));
        ms += 10;
      }
      return ms;
    }

    expect(await thinkMs(), await thinkMs());
  });

  test('without a builder the answer is the not-ready fallback', () async {
    final events = await drain(
      AnswerStream(clock: clock).run(ask('quote reliance')),
    );
    expect([for (final e in events) e['e']], ['start', 'card', 'done']);
    expect((events[1]['card']! as Map)['type'], 'fallback');
  });
}
