import 'package:flutter/foundation.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/domain/ask_topic.dart';

sealed class AiEvent {
  const AiEvent();
}

@immutable
final class AnswerStarted extends AiEvent {
  const AnswerStarted({
    required this.answerId,
    required this.intent,
    required this.serverTime,
  });

  final String answerId;
  final String intent;
  final DateTime serverTime;

  @override
  bool operator ==(Object other) =>
      other is AnswerStarted &&
      other.answerId == answerId &&
      other.intent == intent &&
      other.serverTime == serverTime;

  @override
  int get hashCode => Object.hash(answerId, intent, serverTime);
}

/// Appends [text] to the last paragraph of card [cardId]; `\n\n` starts a
/// new paragraph.
@immutable
final class TextDelta extends AiEvent {
  const TextDelta({required this.cardId, required this.text});

  final String cardId;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is TextDelta && other.cardId == cardId && other.text == text;

  @override
  int get hashCode => Object.hash(cardId, text);
}

@immutable
final class AnswerDone extends AiEvent {
  const AnswerDone({
    required this.cards,
    required this.topic,
    required this.chips,
  });

  final int cards;
  final AskTopic topic;
  final List<String> chips;

  @override
  bool operator ==(Object other) =>
      other is AnswerDone &&
      other.cards == cards &&
      other.topic == topic &&
      listEquals(other.chips, chips);

  @override
  int get hashCode => Object.hash(cards, topic, Object.hashAll(chips));
}

/// The answer ended early. Cards already received stay on screen.
@immutable
final class AnswerFailed extends AiEvent {
  const AnswerFailed(this.error, {required this.retryable});

  final AppError error;
  final bool retryable;

  @override
  bool operator ==(Object other) =>
      other is AnswerFailed &&
      other.error == error &&
      other.retryable == retryable;

  @override
  int get hashCode => Object.hash(error, retryable);
}

final class CardAdded extends AiEvent {
  const CardAdded(this.card);
  final AiCard card;
  @override
  bool operator ==(Object other) => other is CardAdded && other.card == card;
  @override
  int get hashCode => card.hashCode;
}
