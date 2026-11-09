import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_data_providers.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_repository.dart';
import 'package:stock_pulse/features/ai_chat/domain/ask_topic.dart';
import 'package:stock_pulse/features/ai_chat/domain/attachment_pick.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_history.dart';

import '../../helpers/fake_crash_reporter.dart';

/// In-memory history with the same paging rules as the device store.
class FakeHistory implements ChatHistory {
  FakeHistory([List<ChatAnswer>? answers]) : all = answers ?? [];
  final List<ChatAnswer> all;
  Object? readError;
  Object? olderError;
  Object? saveError;
  int clears = 0;
  Completer<void>? olderGate;

  @override
  Future<ChatPage> read({String? beforeId, required int limit}) async {
    if (beforeId == null && readError != null) _throwFakeError(readError!);
    if (beforeId != null) {
      if (olderGate case final gate?) await gate.future;
      if (olderError != null) _throwFakeError(olderError!);
    }
    final end = beforeId == null
        ? all.length
        : all.indexWhere((a) => a.id == beforeId);
    final start = (end - limit).clamp(0, end);
    return (answers: all.sublist(start, end), hasMore: start > 0);
  }

  @override
  Future<void> save(ChatAnswer answer) async {
    if (saveError != null) _throwFakeError(saveError!);
    final i = all.indexWhere((a) => a.id == answer.id);
    i < 0 ? all.add(answer) : all[i] = answer;
  }

  @override
  Future<void> clear() async {
    clears++;
    all.clear();
  }
}

Never _throwFakeError(Object error) => switch (error) {
  final Error value => throw value,
  final Exception value => throw value,
  _ => throw StateError(error.toString()),
};

class FakeAiRepository implements AiRepository {
  final streams = <StreamController<AiEvent>>[];
  final questions = <String>[];
  StreamController<AiEvent> get last => streams.last;
  @override
  Stream<AiEvent> ask(String question, {AskTopic? topic}) {
    questions.add(question);
    final stream = StreamController<AiEvent>(sync: true);
    streams.add(stream);
    return stream.stream;
  }

  Future<void> closeAll() async {
    for (final s in streams) {
      await s.close();
    }
  }
}

ChatAnswer storedAnswer(int i, {List<AiCard> cards = const []}) => ChatAnswer(
  id: 'a$i',
  question: 'Question $i',
  createdAt: DateTime.utc(2026, 1, 1, 0, 0, i),
  status: AnswerStatus.complete,
  cards: cards,
);

AiCard textCard(String id, {String text = '', String title = 'Theta'}) =>
    AiCard(
      id: id,
      type: 'text',
      title: title,
      fallbackText: '',
      body: {
        'paragraphs': [if (text.isNotEmpty) text],
      },
    );

PickedFile pickedFile(String name, int size) =>
    (name: name, size: size, bytes: Uint8List(size.clamp(0, 8)));

List<Override> chatOverrides({
  required FakeAiRepository repo,
  required FakeHistory history,
  FakeCrashReporter? crash,
  Future<PickedFile?> Function()? picker,
}) => [
  aiRepositoryProvider.overrideWithValue(repo),
  chatHistoryProvider.overrideWithValue(history),
  analyticsSinksProvider.overrideWithValue(const []),
  crashReporterProvider.overrideWithValue(crash ?? FakeCrashReporter()),
  if (picker != null) attachmentPickerProvider.overrideWithValue(picker),
];
