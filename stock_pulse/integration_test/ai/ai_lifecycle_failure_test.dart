import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_providers.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';

import 'ai_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'backgrounding an AI answer cancels its stream and allows retry',
    (tester) async {
      final server = await TestServer.start(debug: true);
      addTearDown(server.close);
      final container = await mountAiApp(tester, server);
      container.read(goRouterProvider).go(const AiChatRoute().location);
      await tester.pumpAndSettle();

      final chat = container.read(chatControllerProvider.notifier);
      chat.ask('What does the NIFTY chain say?');
      await waitForWidget(tester, () {
        final answers = container.read(chatControllerProvider).value?.answers;
        return answers != null &&
            answers.isNotEmpty &&
            answers.last.cards.isNotEmpty;
      }, reason: 'first partial AI card');
      expect(server.server.aiAnswers.active, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      await eventually(() => server.server.aiAnswers.active == 0);
      final answer = container
          .read(chatControllerProvider)
          .requireValue
          .answers
          .last;
      expect(answer.status, AnswerStatus.stopped);
      expect(answer.cards, isNotEmpty);
      expect(find.text('Retry'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      chat.retry(answer.id);
      expect(
        container.read(chatControllerProvider).requireValue.answers.last.status,
        AnswerStatus.sending,
      );
      await chat.stop();
      await eventually(() => server.server.aiAnswers.active == 0);
    },
  );
}
