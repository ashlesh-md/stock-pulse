import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_attachment.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_answer_view.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/typing_indicator.dart';

import '../../../helpers/sp_app.dart';

ChatAnswer _answer({
  AnswerStatus status = AnswerStatus.sending,
  List<AiCard> cards = const [],
  List<ChatAttachment> attachments = const [],
  bool retryable = true,
}) => ChatAnswer(
  id: 'answer-1',
  question: 'Explain this chart',
  createdAt: DateTime.utc(2026),
  status: status,
  cards: cards,
  attachments: attachments,
  retryable: retryable,
);

void main() {
  testWidgets('sending answer shows attachment, sending state and thinker', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        ChatAnswerView(
          answer: _answer(
            attachments: const [ChatAttachment(name: 'chart.png', size: 128)],
          ),
          onRetry: () {},
          onExplain: (_) {},
        ),
      ),
    );

    expect(find.text('Explain this chart'), findsOneWidget);
    expect(find.text('chart.png'), findsOneWidget);
    expect(find.text('Sending…'), findsOneWidget);
    expect(find.text('Thinking…'), findsOneWidget);
    expect(find.byType(TypingIndicator), findsOneWidget);
  });

  testWidgets('streaming card gets progress while stopped answer is labeled', (
    tester,
  ) async {
    final card = AiCard(
      id: 'card-1',
      type: 'text',
      title: 'Outlook',
      fallbackText: 'The view is forming.',
    );
    await tester.pumpWidget(
      spApp(
        ChatAnswerView(
          answer: _answer(status: AnswerStatus.streaming, cards: [card]),
          onRetry: () {},
          onExplain: (_) {},
        ),
      ),
    );
    expect(find.text('The view is forming.'), findsOneWidget);
    expect(find.byType(TypingIndicator), findsNothing);

    await tester.pumpWidget(
      spApp(
        ChatAnswerView(
          answer: _answer(status: AnswerStatus.stopped, cards: [card]),
          onRetry: () {},
          onExplain: (_) {},
        ),
      ),
    );
    expect(find.text('Answer stopped'), findsOneWidget);
  });
}
