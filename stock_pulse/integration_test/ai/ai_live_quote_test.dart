import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';

import 'ai_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two visible RELIANCE cards share one quote subscription and '
      'release it when scrolled away', (tester) async {
    final server = await TestServer.start(debug: true);
    addTearDown(server.close);
    CountingOrders.reset();
    final client = HttpClient();
    addTearDown(client.close);
    final container = await mountAiApp(tester, server);
    final router = container.read(goRouterProvider);
    router.go(const AiChatRoute().location);
    await tester.pumpAndSettle();
    expect(container.read(screenVisibleProvider(ScreenId.ai)), isTrue);

    await askAi(container, tester, 'Quote RELIANCE');
    expectLatestAnswer(container, AnswerStatus.complete);
    expect(quoteCardCount(container), 1);
    await askAi(container, tester, 'Quote RELIANCE');
    await waitForWidget(tester, () => quoteCardCount(container) >= 2);
    expect(quoteViews(), findsNWidgets(2));
    await tester.ensureVisible(quoteViews().last);
    await tester.pumpAndSettle();
    await waitForServer(
      tester,
      client,
      server.config.restBase.resolve('/debug/subscriptions'),
      (data) => quoteIds(data).contains('RELIANCE'),
      'RELIANCE quote subscription',
    );
    final active = await readDebug(client, server.config.restBase);
    expect(quoteIds(active).where((id) => id == 'RELIANCE'), hasLength(1));

    await tester.ensureVisible(quoteViews().first);
    await tester.pumpAndSettle();
    await waitForServer(
      tester,
      client,
      server.config.restBase.resolve('/debug/subscriptions'),
      (data) => quoteIds(data).contains('RELIANCE'),
      'RELIANCE subscription while the other card is shown',
    );
    await askAi(container, tester, 'Quote TCS');
    await askAi(container, tester, 'Quote TCS');
    await waitForServer(
      tester,
      client,
      server.config.restBase.resolve('/debug/subscriptions'),
      (data) => !quoteIds(data).contains('RELIANCE'),
      'RELIANCE quote release after both cards leave the viewport',
    );
  });
}
