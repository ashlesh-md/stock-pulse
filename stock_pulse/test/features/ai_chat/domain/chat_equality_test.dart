import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';

AiCard _card() => AiCard.fromJson({
  'id': 'c',
  'v': 1,
  'type': 'quote',
  'title': 'RELIANCE',
  'fallbackText': '',
  'body': {'ltp': 1486.1},
  'asOf': 1,
  'instruments': ['RELIANCE'],
  'actions': [
    {
      'kind': 'trade',
      'label': 'Buy',
      'args': {'id': 'RELIANCE'},
    },
  ],
});

void main() {
  test('cards and actions are equal by value and survive JSON', () {
    final card = _card();
    expect(card, _card());
    expect(card.hashCode, _card().hashCode);
    expect(AiCard.fromJson(card.toJson()), card);
    final action = card.actions.single;
    expect(AiAction.fromJson(action.toJson()), action);
    expect(action.hashCode, AiAction.fromJson(action.toJson())!.hashCode);
  });

  test('CardAdded compares its card', () {
    expect(CardAdded(_card()), CardAdded(_card()));
    expect(CardAdded(_card()).hashCode, CardAdded(_card()).hashCode);
  });

  test('a stored answer restores its cards', () {
    final answer = ChatAnswer(
      id: 'a',
      question: 'Quote RELIANCE',
      createdAt: DateTime.utc(2026),
      status: AnswerStatus.complete,
      cards: [_card()],
    );
    expect(ChatAnswer.fromJson(answer.toJson()), answer);
  });
}
