import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_providers.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/strategy/presentation/screens/strategy_builder_screen.dart';

import 'ai_test_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI cards and strategy builder fit at 2x text scale', (
    tester,
  ) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    final server = await TestServer.start(debug: true);
    addTearDown(server.close);
    final container = await mountAiApp(tester, server);
    container.read(goRouterProvider).go(const AiChatRoute().location);
    await tester.pumpAndSettle();

    await tester.tap(find.text('What does the NIFTY chain say?'));
    await waitForWidget(tester, () {
      final state = container.read(chatControllerProvider).value;
      return state != null &&
          state.answers.isNotEmpty &&
          !state.answers.last.busy;
    }, reason: 'large-text AI answer');
    expectLatestAnswer(container, AnswerStatus.complete);
    expect(tester.takeException(), isNull);

    final payoff = find.text('Payoff of a NIFTY straddle');
    await tester.ensureVisible(payoff);
    await tester.pumpAndSettle();
    await tester.tap(payoff);
    await waitForWidget(
      tester,
      () => find.text('View payoff').evaluate().isNotEmpty,
    );
    final openBuilder = find.text('View payoff');
    await tester.ensureVisible(openBuilder);
    await tester.pumpAndSettle();
    await tester.tap(openBuilder);
    await waitForWidget(
      tester,
      () => find.byType(StrategyBuilderScreen).evaluate().isNotEmpty,
      reason: 'large-text strategy builder',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
