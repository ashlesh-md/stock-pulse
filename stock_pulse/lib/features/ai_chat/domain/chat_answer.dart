import 'package:flutter/foundation.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_attachment.dart';

enum AnswerStatus { sending, streaming, complete, failed, stopped }

const Object _keep = Object();

@immutable
class ChatAnswer {
  ChatAnswer({
    required this.id,
    required this.question,
    required this.createdAt,
    this.status = AnswerStatus.sending,
    List<AiCard> cards = const [],
    List<ChatAttachment> attachments = const [],
    this.retryable = true,
    this.error,
  }) : cards = List.unmodifiable(cards),
       attachments = List.unmodifiable(attachments);
  final String id;
  final String question;
  final DateTime createdAt;
  final AnswerStatus status;
  final List<AiCard> cards;
  final List<ChatAttachment> attachments;
  final bool retryable;

  /// Why the last attempt failed; kept in memory only, not in history.
  final AppError? error;
  bool get busy =>
      status == AnswerStatus.sending || status == AnswerStatus.streaming;
  ChatAnswer copyWith({
    AnswerStatus? status,
    List<AiCard>? cards,
    bool? retryable,
    Object? error = _keep,
  }) => ChatAnswer(
    id: id,
    question: question,
    createdAt: createdAt,
    status: status ?? this.status,
    cards: cards ?? this.cards,
    attachments: attachments,
    retryable: retryable ?? this.retryable,
    error: identical(error, _keep) ? this.error : error as AppError?,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'question': question,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'status': status.name,
    'cards': cards.map((c) => c.toJson()).toList(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'retryable': retryable,
  };
  factory ChatAnswer.fromJson(Map<String, Object?> json) {
    final status =
        AnswerStatus.values.asNameMap()[json['status']] ?? AnswerStatus.failed;
    return ChatAnswer(
      id: json['id']! as String,
      question: json['question']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt']! as int,
        isUtc: true,
      ),
      status: status == AnswerStatus.sending || status == AnswerStatus.streaming
          ? AnswerStatus.stopped
          : status,
      cards: [
        for (final c in json['cards']! as List)
          AiCard.fromJson(c as Map<String, Object?>),
      ],
      attachments: [
        for (final a in json['attachments'] as List? ?? const [])
          ChatAttachment.fromJson(a as Map<String, Object?>),
      ],
      retryable: json['retryable'] as bool? ?? true,
    );
  }
  @override
  bool operator ==(Object other) =>
      other is ChatAnswer &&
      id == other.id &&
      question == other.question &&
      createdAt == other.createdAt &&
      status == other.status &&
      listEquals(cards, other.cards) &&
      listEquals(attachments, other.attachments) &&
      retryable == other.retryable &&
      error == other.error;
  @override
  int get hashCode => Object.hash(
    id,
    question,
    createdAt,
    status,
    Object.hashAll(cards),
    Object.hashAll(attachments),
    retryable,
    error,
  );
}
