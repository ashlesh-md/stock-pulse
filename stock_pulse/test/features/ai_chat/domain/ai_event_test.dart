import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';
import 'package:stock_pulse/features/ai_chat/domain/ask_topic.dart';

void main() {
  group('AskTopic', () {
    test('round-trips through JSON and drops null fields', () {
      const topic = AskTopic(underlying: 'NIFTY', expiry: '2026-11-10');
      expect(AskTopic.fromJson(topic.toJson()), topic);
      expect(const AskTopic(underlying: 'NIFTY').toJson(), {
        'underlying': 'NIFTY',
      });
      expect(AskTopic.fromJson(const {}), const AskTopic());
    });

    test('is equal by value', () {
      expect(
        const AskTopic(underlying: 'NIFTY').hashCode,
        const AskTopic(underlying: 'NIFTY').hashCode,
      );
      expect(
        const AskTopic(underlying: 'NIFTY'),
        isNot(const AskTopic(underlying: 'NIFTY', expiry: '2026-11-10')),
      );
    });
  });

  group('events are equal by value', () {
    test('AnswerStarted', () {
      final a = AnswerStarted(
        answerId: 'a1',
        intent: 'chain',
        serverTime: DateTime.utc(2026, 11, 7),
      );
      final b = AnswerStarted(
        answerId: 'a1',
        intent: 'chain',
        serverTime: DateTime.utc(2026, 11, 7),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          AnswerStarted(
            answerId: 'a2',
            intent: 'chain',
            serverTime: DateTime.utc(2026, 11, 7),
          ),
        ),
      );
    });

    test('TextDelta', () {
      const a = TextDelta(cardId: 'a1.c1', text: 'PCR ');
      expect(a, const TextDelta(cardId: 'a1.c1', text: 'PCR '));
      expect(
        a.hashCode,
        const TextDelta(cardId: 'a1.c1', text: 'PCR ').hashCode,
      );
      expect(a, isNot(const TextDelta(cardId: 'a1.c1', text: 'max')));
    });

    test('AnswerDone', () {
      const a = AnswerDone(
        cards: 2,
        topic: AskTopic(underlying: 'NIFTY'),
        chips: ['Explain PCR'],
      );
      const b = AnswerDone(
        cards: 2,
        topic: AskTopic(underlying: 'NIFTY'),
        chips: ['Explain PCR'],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(const AnswerDone(cards: 2, topic: AskTopic(), chips: [])),
      );
    });

    test('AnswerFailed', () {
      const a = AnswerFailed(NetworkError(), retryable: true);
      expect(a, const AnswerFailed(NetworkError(), retryable: true));
      expect(
        a.hashCode,
        const AnswerFailed(NetworkError(), retryable: true).hashCode,
      );
      expect(a, isNot(const AnswerFailed(NetworkError(), retryable: false)));
    });
  });
}
