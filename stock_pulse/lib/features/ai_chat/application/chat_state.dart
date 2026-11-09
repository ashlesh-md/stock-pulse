import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/ai_chat/domain/ask_topic.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';

/// The loaded part of the conversation, oldest first.
@immutable
class ChatState {
  ChatState({
    List<ChatAnswer> answers = const [],
    List<String> chips = const [],
    this.topic = const AskTopic(),
    this.hasOlder = false,
    this.loadingOlder = false,
    this.historyFailed = false,
  }) : answers = List.unmodifiable(answers),
       chips = List.unmodifiable(chips);
  final List<ChatAnswer> answers;
  final List<String> chips;
  final AskTopic topic;

  /// Older answers remain on the device and load on scroll-up.
  final bool hasOlder;
  final bool loadingOlder;
  final bool historyFailed;
  late final Map<String, ChatAnswer> _byId = {for (final a in answers) a.id: a};
  ChatAnswer? answer(String id) => _byId[id];
  bool get busy => answers.any((a) => a.busy);

  /// What the list needs to lay itself out. It changes when an answer or a
  /// card is added, not on every streamed text delta.
  ChatOutline get outline => ChatOutline(
    ids: [for (final a in answers) a.id],
    lastCards: answers.lastOrNull?.cards.length ?? 0,
    busy: busy,
    chips: chips,
    hasOlder: hasOlder,
    loadingOlder: loadingOlder,
    historyFailed: historyFailed,
  );

  ChatState copyWith({
    List<ChatAnswer>? answers,
    List<String>? chips,
    AskTopic? topic,
    bool? hasOlder,
    bool? loadingOlder,
    bool? historyFailed,
  }) => ChatState(
    answers: answers ?? this.answers,
    chips: chips ?? this.chips,
    topic: topic ?? this.topic,
    hasOlder: hasOlder ?? this.hasOlder,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    historyFailed: historyFailed ?? this.historyFailed,
  );
  @override
  bool operator ==(Object other) =>
      other is ChatState &&
      listEquals(answers, other.answers) &&
      listEquals(chips, other.chips) &&
      topic == other.topic &&
      hasOlder == other.hasOlder &&
      loadingOlder == other.loadingOlder &&
      historyFailed == other.historyFailed;
  @override
  int get hashCode => Object.hash(
    Object.hashAll(answers),
    Object.hashAll(chips),
    topic,
    hasOlder,
    loadingOlder,
    historyFailed,
  );
}

@immutable
class ChatOutline {
  ChatOutline({
    required List<String> ids,
    required this.lastCards,
    required this.busy,
    required List<String> chips,
    required this.hasOlder,
    required this.loadingOlder,
    required this.historyFailed,
  }) : ids = List.unmodifiable(ids),
       chips = List.unmodifiable(chips);
  final List<String> ids;

  /// Cards in the newest answer; a rise means a new card arrived.
  final int lastCards;
  final bool busy;
  final List<String> chips;
  final bool hasOlder;
  final bool loadingOlder;
  final bool historyFailed;
  @override
  bool operator ==(Object other) =>
      other is ChatOutline &&
      listEquals(ids, other.ids) &&
      lastCards == other.lastCards &&
      busy == other.busy &&
      listEquals(chips, other.chips) &&
      hasOlder == other.hasOlder &&
      loadingOlder == other.loadingOlder &&
      historyFailed == other.historyFailed;
  @override
  int get hashCode => Object.hash(
    Object.hashAll(ids),
    lastCards,
    busy,
    Object.hashAll(chips),
    hasOlder,
    loadingOlder,
    historyFailed,
  );
}
