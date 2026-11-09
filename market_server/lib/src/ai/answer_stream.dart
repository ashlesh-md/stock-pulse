import 'dart:math';

import 'package:market_server/src/ai/answer_builder.dart';
import 'package:market_server/src/ai/answer_plan.dart';
import 'package:market_server/src/ai/ask_request.dart';
import 'package:market_server/src/market_clock.dart';

/// Streams one answer as `start`, `card`, `delta`…, `done` events with
/// typing-like delays. Every wait goes through [MarketClock.delay], so
/// tests drive time with `FakeMarketClock`. With no builder every answer is
/// a "not ready" fallback.
class AnswerStream {
  AnswerStream({
    AnswerBuilder? builder,
    MarketClock? clock,
    Random Function(String question)? seedFor,
  }) : _builder = builder,
       _clock = clock ?? MarketClock(mode: ClockMode.real),
       _seedFor = seedFor ?? _hashSeed;

  final AnswerBuilder? _builder;
  final MarketClock _clock;
  final Random Function(String) _seedFor;
  var _active = 0;
  var _seq = 0;

  static const _cardGap = Duration(milliseconds: 150);
  static const _deltaGap = Duration(milliseconds: 40);

  /// Answers being streamed right now (`activeAiAnswers`).
  int get active => _active;

  /// The answer to [req]. Cancelling the subscription stops the generator at
  /// its next `yield` and `active` drops in `finally`. [debugErrorAfterCard]
  /// (debug servers only) emits `error` `debug_fault` after that card.
  Stream<Map<String, Object?>> run(
    AskRequest req, {
    int? debugErrorAfterCard,
  }) async* {
    _active++;
    try {
      final rng = _seedFor(req.question);
      await _clock.delay(Duration(milliseconds: 300 + rng.nextInt(401)));
      final answerId = 'a${++_seq}';
      final builder = _builder;
      final serverTime =
          (builder?.reads.wallNow() ?? _clock.wallNow()).millisecondsSinceEpoch;

      final String intent;
      final AnswerPlan plan;
      try {
        if (builder == null) {
          intent = 'unknown';
          plan = _notReady(answerId);
        } else {
          final parsed = builder.parse(req.question, req.context);
          intent = parsed.name;
          plan = builder.build(parsed, answerId, ctx: req.context);
        }
      } on Object {
        // Any bug in parse/build, Error or Exception, must end this one
        // answer with an `error` event, never the whole stream.
        yield _start(answerId, 'unknown', serverTime);
        yield _error('internal', 'Something went wrong. Try again.');
        return;
      }

      yield _start(answerId, intent, serverTime);
      var sent = 0;
      for (final draft in plan.cards) {
        if (sent > 0) await _clock.delay(_cardGap);
        yield {'e': 'card', 'card': draft.card};
        final cardId = draft.card['id'];
        for (final chunk in draft.textChunks) {
          await _clock.delay(_deltaGap);
          yield {'e': 'delta', 'cardId': cardId, 'text': chunk};
        }
        sent++;
        if (debugErrorAfterCard != null && sent == debugErrorAfterCard) {
          yield _error('debug_fault', 'Debug fault after card $sent');
          return;
        }
      }
      await _clock.delay(_cardGap);
      yield {
        'e': 'done',
        'cards': sent,
        'topic': plan.topic.toJson(),
        'chips': plan.chips,
      };
    } finally {
      _active--;
    }
  }

  Map<String, Object?> _start(String answerId, String intent, int t) => {
    'e': 'start',
    'answerId': answerId,
    'intent': intent,
    'serverTime': t,
  };

  Map<String, Object?> _error(String code, String message) => {
    'e': 'error',
    'code': code,
    'message': message,
    'retryable': true,
  };

  AnswerPlan _notReady(String answerId) {
    const message = 'AI answers are not ready yet.';
    return AnswerPlan(
      cards: [
        CardDraft({
          'id': '$answerId.c1',
          'type': 'fallback',
          'v': 1,
          'title': 'Not ready',
          'asOf': null,
          'instruments': const <String>[],
          'fallbackText': message,
          'actions': const <Object>[],
          'body': {'message': message, 'chips': const <String>[]},
        }),
      ],
      topic: const AskContext(),
      chips: const [],
    );
  }
}

/// FNV-1a over the UTF-16 units: stable across runs, unlike String.hashCode.
Random _hashSeed(String q) {
  var h = 0x811c9dc5;
  for (final u in q.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0xffffffff;
  }
  return Random(h);
}
