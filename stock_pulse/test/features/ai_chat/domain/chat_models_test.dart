import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_attachment.dart';

void main() {
  test('unknown cards preserve readable fallback and drop unsafe actions', () {
    final card = AiCard.fromJson({
      'id': 'c',
      'type': 'future',
      'v': 2,
      'fallbackText': 'Readable fallback',
      'actions': [
        {'kind': 'place_order', 'label': 'Trade'},
      ],
    });
    expect(card.type, 'unknown');
    expect(card.text, 'Readable fallback');
    expect(card.actions, isEmpty);
  });
  test('C3 a known card type at v 2 is read as unknown', () {
    final card = AiCard.fromJson({
      'id': 'c',
      'type': 'quote',
      'v': 2,
      'fallbackText': 'TCS 3,500',
    });
    expect(card.type, 'unknown');
    expect(card.text, 'TCS 3,500');
  });

  test('attachment metadata survives history without storing file content', () {
    const attachment = ChatAttachment(name: 'chart.png', size: 32);
    final answer = ChatAnswer(
      id: 'a',
      question: 'NIFTY',
      createdAt: DateTime.utc(2026),
      attachments: [attachment],
    );
    final restored = ChatAnswer.fromJson(answer.toJson());
    expect(restored.status, AnswerStatus.stopped);
    expect(restored.attachments.single, attachment);
    expect(restored.attachments.single.bytes, isNull);
    expect(attachment.isImage, isTrue);
    expect(const ChatAttachment(name: 'notes.pdf', size: 1).isImage, isFalse);
    expect(
      attachment.hashCode,
      ChatAttachment.fromJson(attachment.toJson()).hashCode,
    );
  });
  test('delta text appends and card JSON round trips', () {
    final card = AiCard.fromJson({
      'id': 'c',
      'v': 1,
      'type': 'text',
      'title': 'T',
      'fallbackText': '',
      'body': {'paragraphs': <String>[]},
    }).append('Hello').append(' world');
    expect(card.text, 'Hello world');
    expect(AiCard.fromJson(card.toJson()).text, 'Hello world');
  });
}
