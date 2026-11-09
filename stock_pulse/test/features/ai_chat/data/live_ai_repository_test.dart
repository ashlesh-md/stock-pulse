import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/features/ai_chat/data/live_ai_repository.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';
import 'package:stock_pulse/features/ai_chat/domain/ask_topic.dart';

class _Poster {
  final calls = <({String path, Object body})>[];
  StreamController<Map<String, Object?>> lines = StreamController();

  Stream<Map<String, Object?>> call(String path, Object body) {
    calls.add((path: path, body: body));
    return lines.stream;
  }

  Future<void> close() => lines.close();
}

void main() {
  late _Poster poster;
  late LiveAiRepository repo;

  setUp(() {
    poster = _Poster();
    repo = LiveAiRepository(
      postLines: poster.call,
      newRequestId: () => 'req-1',
    );
  });
  tearDown(() => poster.close());

  Future<List<AiEvent>> ask(
    List<Map<String, Object?>> lines, {
    AppError? error,
  }) {
    final events = repo.ask('nifty chain').toList();
    lines.forEach(poster.lines.add);
    if (error != null) poster.lines.addError(error);
    unawaited(poster.lines.close());
    return events;
  }

  test('posts the question, request id and topic to the ask path', () async {
    final events = repo
        .ask('pcr?', topic: const AskTopic(underlying: 'NIFTY'))
        .toList();
    await poster.lines.close();
    await events;
    expect(poster.calls.single.path, '/api/v1/ai/ask');
    expect(poster.calls.single.body, {
      'question': 'pcr?',
      'requestId': 'req-1',
      'context': {'underlying': 'NIFTY'},
    });
  });

  test('leaves out the context when there is no topic', () async {
    await ask(const []);
    expect(poster.calls.single.body, {
      'question': 'nifty chain',
      'requestId': 'req-1',
    });
  });

  test('maps start, delta and done lines to events in order (C4)', () async {
    final events = await ask(const [
      {'e': 'start', 'answerId': 'a1', 'intent': 'chain', 'serverTime': 0},
      {'e': 'delta', 'cardId': 'a1.c3', 'text': 'PCR 0.92'},
      {
        'e': 'done',
        'cards': 3,
        'topic': {'underlying': 'NIFTY'},
        'chips': ['Explain PCR'],
      },
    ]);
    expect(events, [
      AnswerStarted(
        answerId: 'a1',
        intent: 'chain',
        serverTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      const TextDelta(cardId: 'a1.c3', text: 'PCR 0.92'),
      const AnswerDone(
        cards: 3,
        topic: AskTopic(underlying: 'NIFTY'),
        chips: ['Explain PCR'],
      ),
    ]);
  });

  test('an error line becomes AnswerFailed with the server code', () async {
    final events = await ask(const [
      {'e': 'error', 'code': 'internal', 'message': 'boom', 'retryable': false},
    ]);
    final failed = events.single as AnswerFailed;
    expect(failed.retryable, isFalse);
    expect(
      failed.error,
      isA<ServerError>().having((e) => e.code, 'code', 'internal'),
    );
  });

  test('unknown and card lines are skipped', () async {
    final events = await ask(const [
      {'e': 'card', 'card': <String, Object?>{}},
      {'e': 'progress'},
      {'cardId': 'x'},
      {'e': 'delta', 'cardId': 'a1.c1', 'text': 'hi'},
    ]);
    expect(events, [const TextDelta(cardId: 'a1.c1', text: 'hi')]);
  });

  test('a malformed known line ends the answer with a ParseError', () async {
    final events = await ask(const [
      {'e': 'delta', 'cardId': 'a1.c1'},
      {'e': 'delta', 'cardId': 'a1.c1', 'text': 'never read'},
    ]);
    expect(events, [const AnswerFailed(ParseError(), retryable: true)]);
  });

  test('a stream error becomes a retryable AnswerFailed (C2)', () async {
    final events = await ask(const [
      {'e': 'delta', 'cardId': 'a1.c1', 'text': 'PCR'},
    ], error: const NetworkError('The answer stopped'));
    expect(events.last, isA<AnswerFailed>());
    final failed = events.last as AnswerFailed;
    expect(failed.retryable, isTrue);
    expect(failed.error, isA<NetworkError>());
    expect(events, hasLength(2));
  });

  test('cancelling the answer cancels the line stream', () async {
    var cancelled = false;
    poster.lines = StreamController(onCancel: () => cancelled = true);
    final sub = repo.ask('nifty chain').listen((_) {});
    poster.lines.add(const {'e': 'delta', 'cardId': 'a1.c1', 'text': 'a'});
    await pumpEventQueue();
    await sub.cancel();
    expect(cancelled, isTrue);
  });

  test('an error that is not an AppError is passed through', () async {
    final events = repo.ask('nifty chain').toList();
    poster.lines.addError(StateError('bug'));
    await poster.lines.close();
    await expectLater(events, throwsStateError);
  });

  test('pausing the answer pauses the line stream', () async {
    poster.lines = StreamController();
    final sub = repo.ask('nifty chain').listen((_) {});
    await pumpEventQueue();
    sub.pause();
    expect(poster.lines.isPaused, isTrue);
    sub.resume();
    expect(poster.lines.isPaused, isFalse);
    await sub.cancel();
  });

  test('default request ids are 32 random hex characters', () async {
    final live = LiveAiRepository(postLines: poster.call);
    final events = live.ask('a').toList();
    await poster.lines.close();
    await events;
    final body = poster.calls.single.body as Map<String, Object?>;
    final id = body['requestId']! as String;
    expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
  });
}
