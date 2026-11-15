import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';

import '../ai/ai_test_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI chat first-card and stream-complete performance trace', (
    tester,
  ) async {
    final server = await TestServer.start(debug: true);
    addTearDown(server.close);
    final container = await mountAiApp(tester, server);
    container.read(goRouterProvider).go(const AiChatRoute().location);
    await tester.pumpAndSettle();

    await binding.watchPerformance(() async {
      await askAi(container, tester, 'Explain max pain');
      expectLatestAnswer(container, AnswerStatus.complete);
    }, reportKey: 'chat');
  });
}
