import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/l10n/locales/en/app_strings_en.dart';
import 'package:stock_pulse/features/ai_chat/application/chat_controller.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';
import 'package:stock_pulse/features/ai_chat/domain/ask_topic.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/presentation/screens/ai_chat_screen.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_shell.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/typing_indicator.dart';

import '../../../helpers/sp_app.dart';
import '../chat_fakes.dart';

const _s = AppStringsEn();
final _long = List.filled(40, 'Option sellers collect premium.').join(' ');

/// Pumps past every finite animation; the typing dots and progress rule
/// repeat while an answer is busy, so pumpAndSettle would never return.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  late FakeAiRepository repo;
  late FakeHistory history;
  setUp(() {
    repo = FakeAiRepository();
    history = FakeHistory();
  });
  tearDown(() async => repo.closeAll());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      spApp(
        const AiChatScreen(),
        overrides: chatOverrides(repo: repo, history: history),
      ),
    );
    await settle(tester);
  }

  void seed(int count) => history.all.addAll([
    for (var i = 0; i < count; i++)
      storedAnswer(i, cards: [textCard('c$i', text: _long)]),
  ]);

  Finder pill() => find.text(_s.chat.newAnswer).hitTestable();
  double offset(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .pixels;

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byTooltip(_s.chat.send));
    await tester.pump();
  }

  testWidgets('first open greets and a suggested prompt asks it', (
    tester,
  ) async {
    await open(tester);
    expect(find.text(_s.chat.emptyTitle), findsOneWidget);
    await tester.tap(find.text(_s.chat.suggestions[1]));
    await tester.pump();
    expect(repo.questions, [_s.chat.suggestions[1]]);
    expect(find.text(_s.chat.sending), findsOneWidget);
    expect(find.byType(TypingIndicator), findsOneWidget);
    expect(find.byTooltip(_s.chat.stop), findsOneWidget);
    await tester.tap(find.byTooltip(_s.chat.stop));
    await tester.pump();
    expect(find.text(_s.chat.stopped), findsOneWidget);
  });

  testWidgets('cards stream in, then follow-up chips replace Stop', (
    tester,
  ) async {
    await open(tester);
    await send(tester, 'Explain theta');
    repo.last
      ..add(
        AnswerStarted(
          answerId: 'x',
          intent: 'explain',
          serverTime: DateTime(2026),
        ),
      )
      ..add(CardAdded(textCard('c1')))
      ..add(const TextDelta(cardId: 'c1', text: 'Time decay'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(ChatController.flushEvery);
    await settle(tester);
    expect(find.text('Time decay'), findsOneWidget);

    repo.last.add(
      const AnswerDone(cards: 1, topic: AskTopic(), chips: ['Explain vega']),
    );
    await settle(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text(_s.chat.disclaimer), findsOneWidget);
    await tester.tap(find.text('Explain vega'));
    await tester.pump();
    expect(repo.questions.last, 'Explain vega');
  });

  testWidgets('a growing answer at the bottom stays pinned with no pill', (
    tester,
  ) async {
    seed(6);
    await open(tester);
    await send(tester, 'Long one');
    repo.last.add(CardAdded(textCard('n1')));
    for (var i = 0; i < 5; i++) {
      repo.last.add(TextDelta(cardId: 'n1', text: ' $_long'));
      await tester.pump(ChatController.flushEvery);
    }
    repo.last.add(CardAdded(textCard('n2', title: 'Second')));
    await settle(tester);
    expect(offset(tester), 0);
    expect(pill(), findsNothing);
  });

  testWidgets('the pill shows only for a new card while scrolled up and hides '
      'at the bottom', (tester) async {
    seed(6);
    await open(tester);
    await send(tester, 'Quote RELIANCE');
    await settle(tester);
    expect(pill(), findsNothing);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 500));
    await settle(tester);
    expect(pill(), findsNothing, reason: 'scrolling alone shows nothing');

    repo.last.add(CardAdded(textCard('n1')));
    await settle(tester);
    expect(pill(), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await settle(tester);
    expect(pill(), findsNothing);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 500));
    await settle(tester);
    repo.last.add(CardAdded(textCard('n2')));
    await settle(tester);
    await tester.tap(pill());
    await settle(tester);
    expect(pill(), findsNothing);
    expect(offset(tester), 0);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 500));
    await settle(tester);
    repo.last.add(CardAdded(textCard('n3')));
    await settle(tester);
    expect(pill(), findsOneWidget);

    await tester.tap(pill());
    await tester.pump(const Duration(milliseconds: 32));
    repo.last.add(CardAdded(textCard('n4')));
    await tester.pump(ChatController.flushEvery);
    expect(pill(), findsNothing);
    await settle(tester);
    expect(offset(tester), 0);
    expect(pill(), findsNothing);
  });

  testWidgets('scrolling up loads older answers kept on the device', (
    tester,
  ) async {
    seed(30);
    await open(tester);
    expect(find.text('Question 0'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Question 0'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Question 0'), findsOneWidget);
  });

  testWidgets(
    'composer stays at the bottom while messages scroll and keyboard opens',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      seed(20);
      await open(tester);
      final field = find.byType(TextField);
      final initialBottom = tester.getRect(field).bottom;

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 500));
      await settle(tester);
      expect(tester.getRect(field).bottom, closeTo(initialBottom, 1));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await settle(tester);
      expect(tester.getRect(field).bottom, lessThanOrEqualTo(500));
      expect(tester.getRect(field).height, greaterThan(0));
    },
  );

  testWidgets('only leaving the app stops an answer, not losing focus', (
    tester,
  ) async {
    await open(tester);
    await send(tester, 'NIFTY');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byTooltip(_s.chat.stop), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text(_s.chat.stopped), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('New chat asks first, then deletes the history', (tester) async {
    seed(2);
    await open(tester);
    await tester.tap(find.byTooltip(_s.chat.newChat));
    await settle(tester);
    await tester.tap(find.text(_s.chat.cancel));
    await settle(tester);
    expect(history.clears, 0);
    await tester.tap(find.byTooltip(_s.chat.newChat));
    await settle(tester);
    await tester.tap(find.text(_s.chat.delete));
    await settle(tester);
    expect(history.clears, 1);
    expect(find.text(_s.chat.emptyTitle), findsOneWidget);
  });

  testWidgets('a history that cannot be saved says so', (tester) async {
    history.saveError = Exception('full');
    await open(tester);
    await send(tester, 'NIFTY');
    await tester.pump();
    expect(find.text(_s.chat.historyFailed), findsOneWidget);
  });

  testWidgets('a chat that cannot load offers a retry', (tester) async {
    history.readError = StateError('broken');
    await open(tester);
    expect(find.text(_s.chat.loadingFailed), findsOneWidget);
    history.readError = null;
    await tester.tap(find.text(_s.chat.loadingFailed));
    await settle(tester);
    expect(find.text(_s.chat.emptyTitle), findsOneWidget);
  });

  testWidgets('a failed answer shows Retry and asks again in place', (
    tester,
  ) async {
    await open(tester);
    await send(tester, 'NIFTY');
    unawaited(repo.last.close());
    await settle(tester);
    expect(find.byType(AiCardShell), findsNothing);
    await tester.tap(find.text(_s.chat.retry));
    await tester.pump();
    expect(repo.questions, ['NIFTY', 'NIFTY']);
    expect(find.text(_s.chat.retry), findsNothing);
    expect(
      find.text(_s.chat.sending),
      findsOneWidget,
      reason: AnswerStatus.sending.name,
    );
  });
}
