import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/ai_chat/application/chat_controller.dart';
import 'package:stock_pulse/features/ai_chat/application/chat_state.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_providers.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';
import 'package:stock_pulse/features/ai_chat/domain/ask_topic.dart';
import 'package:stock_pulse/features/ai_chat/domain/attachment_pick.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_limits.dart';

import '../../../helpers/fake_crash_reporter.dart';
import '../chat_fakes.dart';

void main() {
  late FakeAiRepository repo;
  late FakeHistory history;
  late FakeCrashReporter crash;
  late ProviderContainer container;
  Future<PickedFile?> Function() picker = () async => null;

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: chatOverrides(
        repo: repo,
        history: history,
        crash: crash,
        picker: () => picker(),
      ),
    );
    c.listen(chatControllerProvider, (_, _) {});
    return c;
  }

  ChatState state() => container.read(chatControllerProvider).requireValue;
  ChatController controller() =>
      container.read(chatControllerProvider.notifier);

  setUp(() {
    repo = FakeAiRepository();
    history = FakeHistory();
    crash = FakeCrashReporter();
    container = make();
  });
  tearDown(() async {
    container.dispose();
    await repo.closeAll();
  });

  test('history loads one page, then older pages on demand', () async {
    history.all.addAll([for (var i = 0; i < 45; i++) storedAnswer(i)]);
    container.invalidate(chatControllerProvider);
    await container.read(chatControllerProvider.future);
    expect(state().answers, hasLength(ChatLimits.pageSize));
    expect(state().answers.first.id, 'a25');
    expect(state().hasOlder, isTrue);

    history.olderGate = Completer();
    final load = controller().loadOlder();
    expect(state().loadingOlder, isTrue);
    await controller().loadOlder();
    history.olderGate!.complete();
    await load;
    expect(state().answers, hasLength(40));
    expect(state().loadingOlder, isFalse);

    await controller().loadOlder();
    expect(state().answers.first.id, 'a0');
    expect(state().hasOlder, isFalse);
    await controller().loadOlder();
    expect(state().answers, hasLength(45));
  });

  test('older paging keeps at most the newest 50 answers', () async {
    history.all.addAll([for (var i = 0; i < 60; i++) storedAnswer(i)]);
    container.invalidate(chatControllerProvider);
    await container.read(chatControllerProvider.future);
    await controller().loadOlder();
    await controller().loadOlder();
    expect(state().answers, hasLength(ChatLimits.maxAnswers));
    expect(state().answers.first.id, 'a10');
    expect(state().answers.last.id, 'a59');
    expect(state().hasOlder, isFalse);
  });

  test('the 51st answer drops the oldest from the active chat', () async {
    await container.read(chatControllerProvider.future);
    for (var i = 0; i <= ChatLimits.maxAnswers; i++) {
      controller().ask('Question $i');
      repo.last.add(const AnswerDone(cards: 0, topic: AskTopic(), chips: []));
    }
    expect(state().answers, hasLength(ChatLimits.maxAnswers));
    expect(state().answers.first.question, 'Question 1');
    expect(state().answers.last.question, 'Question 50');
  });

  test('a failed older-page read stops further loads', () async {
    history.all.addAll([for (var i = 0; i < 25; i++) storedAnswer(i)]);
    history.olderError = Exception('disk');
    container.invalidate(chatControllerProvider);
    await container.read(chatControllerProvider.future);
    await controller().loadOlder();
    expect(state().hasOlder, isFalse);
    expect(state().loadingOlder, isFalse);
    expect(state().answers, hasLength(20));
  });

  test('an unreadable history opens an empty chat that says so', () async {
    history.readError = Exception('corrupt');
    container.dispose();
    container = make();
    await container.read(chatControllerProvider.future);
    expect(state().answers, isEmpty);
    expect(state().historyFailed, isTrue);
    expect(state().outline.historyFailed, isTrue);
  });

  test('a failed save is flagged and reported', () async {
    history.saveError = Exception('full');
    await container.read(chatControllerProvider.future);
    controller().ask('NIFTY');
    await pumpEventQueue();
    expect(state().historyFailed, isTrue);
    expect(crash.errors.single.reason, 'chat_history_write');
  });

  test('clear empties the chat and the device history', () async {
    history.all.add(storedAnswer(1));
    container.invalidate(chatControllerProvider);
    await container.read(chatControllerProvider.future);
    controller().clear();
    await pumpEventQueue();
    expect(state().answers, isEmpty);
    expect(history.clears, 1);
    expect(history.all, isEmpty);
  });

  test('pickAttachment maps the picker outcome', () async {
    await container.read(chatControllerProvider.future);
    expect(await controller().pickAttachment(), isA<AttachmentCancelled>());
    picker = () async => pickedFile('a.png', 0);
    expect(await controller().pickAttachment(), isA<AttachmentTooLarge>());
    picker = () async => pickedFile('a.png', ChatLimits.maxAttachmentBytes + 1);
    expect(await controller().pickAttachment(), isA<AttachmentTooLarge>());
    picker = () async => throw Exception('denied');
    expect(await controller().pickAttachment(), isA<AttachmentFailed>());
    picker = () async => pickedFile('a.png', 2048);
    final picked = await controller().pickAttachment();
    expect((picked as AttachmentPicked).attachment.name, 'a.png');
    expect(picked.attachment.size, 2048);
  });

  test('state and outline compare by value', () {
    final a = ChatState(answers: [storedAnswer(1)], chips: const ['x']);
    final b = ChatState(answers: [storedAnswer(1)], chips: const ['x']);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.outline, b.outline);
    expect(a.outline.hashCode, b.outline.hashCode);
    expect(a.answer('a1'), storedAnswer(1));
    expect(a.copyWith(loadingOlder: true), isNot(a));
  });
}
