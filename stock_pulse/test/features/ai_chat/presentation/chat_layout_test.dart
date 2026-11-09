import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/di/layout_providers.dart';
import 'package:stock_pulse/app/router/movable_tab_shortcut.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/locales/en/app_strings_en.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/ai_chat/application/chat_controller.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';
import 'package:stock_pulse/features/ai_chat/domain/ask_topic.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/presentation/screens/ai_chat_screen.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_shell.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_follow_ups.dart';

import '../../../helpers/sp_app.dart';
import '../chat_fakes.dart';

const _s = AppStringsEn();
const _width = 440.0;
const _height = 956.0;
final _longQuestion = List.filled(12, 'Why does theta speed up?').join(' ');

void main() {
  late FakeAiRepository repo;
  late FakeHistory history;
  setUp(() {
    repo = FakeAiRepository();
    history = FakeHistory();
  });
  tearDown(() async => repo.closeAll());

  Future<void> open(
    WidgetTester tester, {
    double bottomSafeArea = 0,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = const Size(_width, _height);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(bottom: bottomSafeArea);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      spApp(
        const AiChatScreen(),
        overrides: chatOverrides(repo: repo, history: history),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  Rect bubbleOf(WidgetTester tester, String question) => tester.getRect(
    find
        .ancestor(of: find.text(question), matching: find.byType(DecoratedBox))
        .first,
  );

  testWidgets('answer cards fill the width less a 16 pt gutter, with no '
      'strip kept free on the right', (tester) async {
    history.all.add(storedAnswer(0, cards: [textCard('c0', text: 'Premium')]));
    await open(tester);

    final card = tester.getRect(find.byType(AiCardShell));
    expect(card.left, SpSpace.gutter);
    expect(card.right, _width - SpSpace.gutter);
  });

  testWidgets('on a 390 pt phone the left and right gutters are equal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    history.all.add(storedAnswer(0, cards: [textCard('c0', text: 'Premium')]));
    await tester.pumpWidget(
      spApp(
        const AiChatScreen(),
        overrides: chatOverrides(repo: repo, history: history),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final card = tester.getRect(find.byType(AiCardShell));
    expect(card.left, SpSpace.gutter);
    expect(390 - card.right, card.left);
  });

  testWidgets('a long question wraps in a right-aligned bubble at most 80% '
      'of the list wide; a short one hugs its text', (tester) async {
    history.all.addAll([
      ChatAnswer(
        id: 'long',
        question: _longQuestion,
        createdAt: DateTime.utc(2026),
        status: AnswerStatus.complete,
      ),
      storedAnswer(1),
    ]);
    await open(tester);

    const list = _width - 2 * SpSpace.gutter;
    final long = bubbleOf(tester, _longQuestion);
    expect(long.right, _width - SpSpace.gutter);
    expect(long.width, closeTo(list * 0.8, 1));
    expect(long.height, greaterThan(3 * 24));
    final short = bubbleOf(tester, 'Question 1');
    expect(short.right, _width - SpSpace.gutter);
    expect(short.width, lessThan(list * 0.5));
  });

  testWidgets('messages are 12 pt apart', (tester) async {
    history.all.addAll([
      storedAnswer(0, cards: [textCard('c0', text: 'First')]),
      storedAnswer(1, cards: [textCard('c1', text: 'Second')]),
    ]);
    await open(tester);

    final firstCard = tester.getRect(
      find.ancestor(of: find.text('First'), matching: find.byType(AiCardShell)),
    );
    final nextBubble = bubbleOf(tester, 'Question 1');
    expect(nextBubble.top - firstCard.bottom, SpSpace.s3);
  });

  testWidgets('follow-up chips sit between the newest answer and the '
      'composer and cover neither', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Explain theta');
    await tester.pump();
    await tester.tap(find.byTooltip(_s.chat.send));
    await tester.pump();
    repo.last
      ..add(CardAdded(textCard('c1', text: 'Time decay')))
      ..add(
        const AnswerDone(
          cards: 1,
          topic: AskTopic(),
          chips: ['Explain vega', 'Explain gamma'],
        ),
      );
    await tester.pump(ChatController.flushEvery);
    await tester.pump(const Duration(milliseconds: 600));

    final chips = tester.getRect(find.byType(ChatFollowUps));
    final field = tester.getRect(find.byType(TextField));
    final lastCard = tester.getRect(find.byType(AiCardShell).last);
    expect(
      tester
          .widget<ListView>(
            find.descendant(
              of: find.byType(ChatFollowUps),
              matching: find.byType(ListView),
            ),
          )
          .scrollDirection,
      Axis.horizontal,
    );
    expect(lastCard.bottom, lessThanOrEqualTo(chips.top));
    expect(chips.bottom, lessThanOrEqualTo(field.top));
    expect(find.text('Time decay').hitTestable(), findsOneWidget);
  });

  testWidgets('composer: attach on the left, send on the same line as the '
      'field and disabled until there is text', (tester) async {
    await open(tester);

    IconButton send() => tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, AppIcons.send),
    );
    final field = tester.getRect(find.byType(TextField));
    final sendRect = tester.getRect(find.byTooltip(_s.chat.send));
    final attach = tester.getRect(find.byTooltip(_s.chat.attach));
    expect(sendRect.center.dy, closeTo(field.center.dy, 2));
    expect(attach.right, lessThanOrEqualTo(field.left));
    expect(sendRect.left, greaterThanOrEqualTo(field.right));
    expect(find.byTooltip(_s.chat.send), findsOneWidget);
    expect(send().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Delta?');
    await tester.pump();
    expect(send().onPressed, isNotNull);
  });

  testWidgets('composer stays above the bottom safe area', (tester) async {
    await open(tester, bottomSafeArea: 34);

    final field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(_height - 34));
  });

  testWidgets('composer rides above the keyboard', (tester) async {
    await open(tester, keyboard: 336);

    final field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(_height - 336));
  });

  testWidgets('the floating shortcut rests above the chips and composer, and '
      'the newest card scrolled to the bottom ends above it', (tester) async {
    tester.view.physicalSize = const Size(_width, _height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    history.all.addAll([
      for (var i = 0; i < 6; i++)
        storedAnswer(i, cards: [textCard('c$i', text: _longQuestion)]),
    ]);
    await tester.pumpWidget(
      spApp(
        Stack(
          children: [
            const AiChatScreen(),
            Consumer(
              builder: (context, ref, _) => MovableTabShortcut(
                destinations: const [
                  (AppIcons.watchlist, 'Watchlist'),
                  (AppIcons.options, 'Options'),
                  (AppIcons.ai, 'AI'),
                  (AppIcons.portfolio, 'Portfolio'),
                  (AppIcons.more, 'More'),
                ],
                selectedIndex: 2,
                onSelect: (_) {},
                visible: true,
                dockHeight: ref.watch(chatDockHeightProvider),
              ),
            ),
          ],
        ),
        overrides: chatOverrides(repo: repo, history: history),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField), 'Explain theta');
    await tester.pump();
    await tester.tap(find.byTooltip(_s.chat.send));
    await tester.pump();
    repo.last
      ..add(CardAdded(textCard('new', text: 'Newest card')))
      ..add(
        const AnswerDone(cards: 1, topic: AskTopic(), chips: ['Explain vega']),
      );
    await tester.pump(ChatController.flushEvery);
    await tester.pump(const Duration(milliseconds: 600));

    final shortcut = tester.getRect(find.byTooltip(_s.shell.tabs));
    final chips = tester.getRect(find.byType(ChatFollowUps));
    final newest = tester.getRect(
      find.ancestor(
        of: find.text('Newest card'),
        matching: find.byType(AiCardShell),
      ),
    );
    expect(shortcut.right, lessThanOrEqualTo(_width - SpSpace.s3));
    expect(shortcut.bottom, lessThanOrEqualTo(chips.top));
    expect(newest.bottom, lessThanOrEqualTo(shortcut.top));
    expect(newest.left, SpSpace.gutter);
    expect(_width - newest.right, SpSpace.gutter);
  });
}
