import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_providers.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/presentation/screens/ai_chat_screen.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_shell.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/orders/presentation/screens/order_ticket_screen.dart';
import 'package:stock_pulse/features/strategy/presentation/screens/strategy_builder_screen.dart';

import 'ai_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NIFTY chain AI flow opens payoff and a source-tagged ticket '
      'without placing an order', (tester) async {
    final server = await TestServer.start(debug: true);
    addTearDown(server.close);
    CountingOrders.reset();
    final container = await mountAiApp(tester, server);
    final router = container.read(goRouterProvider);
    router.go(const AiChatRoute().location);
    await tester.pumpAndSettle();

    await tester.tap(find.text('What does the NIFTY chain say?'));
    await waitForWidget(tester, () {
      final answers = container.read(chatControllerProvider).value?.answers;
      return answers != null && answers.isNotEmpty && !answers.last.busy;
    }, reason: 'NIFTY chain answer completion');
    expectLatestAnswer(container, AnswerStatus.complete);
    expect(find.text('Payoff of a NIFTY straddle'), findsOneWidget);
    expect(find.byType(AiCardShell), findsAtLeastNWidgets(2));
    await tester.tap(find.text('Payoff of a NIFTY straddle'));
    await waitForWidget(
      tester,
      () => find.text('View payoff').evaluate().isNotEmpty,
    );
    await tester.ensureVisible(find.text('View payoff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View payoff'));
    await waitForWidget(
      tester,
      () => find.byType(StrategyBuilderScreen).evaluate().isNotEmpty,
    );
    expect(find.textContaining('Max loss'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    router.go(const AiChatRoute().location);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AiChatRoute.path);
    expect(find.byType(AiChatScreen), findsOneWidget);
    final tradeAction = find.text('Trade this strike');
    for (final dy in [400.0, -400.0, 800.0, -800.0]) {
      if (tradeAction.hitTestable().evaluate().isNotEmpty) break;
      await tester.drag(chatList(), Offset(0, dy));
      await tester.pumpAndSettle();
    }
    expect(tradeAction.hitTestable(), findsOneWidget);
    await tester.tap(tradeAction);
    await waitForWidget(
      tester,
      () => find.byType(OrderTicketScreen).evaluate().isNotEmpty,
    );
    final ticket = tester.widget<OrderTicketScreen>(
      find.byType(OrderTicketScreen),
    );
    expect(ticket.args.source, OrderSource.ai);
    expect(CountingOrders.postCount, 0);
  });
}
