import 'dart:async';
import 'dart:math';

import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/ai_chat/data/ai_api.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_repository.dart';
import 'package:stock_pulse/features/ai_chat/domain/ask_topic.dart';

typedef LinePoster = Stream<Map<String, Object?>> Function(
  String path,
  Object body,
);

class LiveAiRepository implements AiRepository {
  LiveAiRepository({required this._postLines, String Function()? newRequestId})
    : _newRequestId = newRequestId ?? _randomRequestId;

  final LinePoster _postLines;
  final String Function() _newRequestId;

  /// Built on a plain controller rather than `async*`: a generator waiting in
  /// `await for` only sees a cancel at its next `yield`, so Stop would not
  /// abort a silent request.
  @override
  Stream<AiEvent> ask(String question, {AskTopic? topic}) {
    final body = {
      'question': question,
      'requestId': _newRequestId(),
      'context': ?topic?.toJson(),
    };
    StreamSubscription<Map<String, Object?>>? lines;
    final events = StreamController<AiEvent>();

    Future<void> fail(AppError error) async {
      events.add(AnswerFailed(error, retryable: true));
      await lines?.cancel();
      await events.close();
    }

    void onLine(Map<String, Object?> line) {
      switch (parseJson(() => aiEventFromLine(line))) {
        case Success(value: final event?):
          events.add(event);
        case Success():
          break;
        case Failure(:final error):
          unawaited(fail(error));
      }
    }

    void onError(Object error, StackTrace stack) => error is AppError
        ? unawaited(fail(error))
        : events.addError(error, stack);

    events
      ..onListen = () {
        final endpoint = aiAskEndpoint(body);
        lines = _postLines(
          endpoint.path,
          endpoint.body!,
        ).listen(onLine, onError: onError, onDone: events.close);
      }
      ..onPause = (() => lines?.pause())
      ..onResume = (() => lines?.resume())
      ..onCancel = (() => lines?.cancel());
    return events.stream;
  }
}

/// Null for a line this client does not handle, so a newer server can add
/// event kinds without breaking older apps.
AiEvent? aiEventFromLine(Map<String, Object?> line) => switch (line['e']) {
  'card' when (line['card'] as Map<String, Object?>).isNotEmpty => CardAdded(
    AiCard.fromJson(line['card']! as Map<String, Object?>),
  ),
  'start' => AnswerStarted(
    answerId: line['answerId']! as String,
    intent: line['intent']! as String,
    serverTime: DateTime.fromMillisecondsSinceEpoch(
      line['serverTime']! as int,
      isUtc: true,
    ),
  ),
  'delta' => TextDelta(
    cardId: line['cardId']! as String,
    text: line['text']! as String,
  ),
  'done' => AnswerDone(
    cards: line['cards']! as int,
    topic: AskTopic.fromJson(line['topic']! as Map<String, Object?>),
    chips: List.unmodifiable(line['chips']! as List<Object?>),
  ),
  'error' => AnswerFailed(
    ServerError(200, line['code']! as String, line['message']! as String),
    retryable: line['retryable']! as bool,
  ),
  _ => null,
};

String _randomRequestId() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}
