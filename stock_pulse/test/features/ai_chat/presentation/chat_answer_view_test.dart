import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/l10n/locales/en/app_strings_en.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_answer_view.dart';

import '../../../helpers/sp_app.dart';

ChatAnswer _failed(AppError? error) => ChatAnswer(
  id: 'a1',
  question: 'Quote RELIANCE',
  createdAt: DateTime.utc(2026),
  status: AnswerStatus.failed,
  error: error,
);

void main() {
  const strings = AppStringsEn();

  testWidgets('a failed answer names an out-of-date server, not a bare retry', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      spApp(
        ChatAnswerView(
          answer: _failed(const ServerError(404, 'http_404', 'raw')),
          onRetry: () => retries++,
          onExplain: (_) {},
        ),
      ),
    );

    expect(find.text(strings.errors.outdated), findsOneWidget);
    expect(find.text('raw'), findsNothing);
    await tester.tap(find.text(strings.chat.retry));
    expect(retries, 1);
  });

  testWidgets('a failed answer without a known error says it was interrupted', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        ChatAnswerView(
          answer: _failed(null),
          onRetry: () {},
          onExplain: (_) {},
        ),
      ),
    );

    expect(find.text(strings.chat.failed), findsOneWidget);
  });
}
