import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/features/ai_chat/application/chat_controller.dart';
import 'package:stock_pulse/features/ai_chat/application/chat_state.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_providers.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';
import 'package:stock_pulse/features/ai_chat/domain/ask_topic.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_limits.dart';

import '../../../helpers/fake_crash_reporter.dart';
import '../chat_fakes.dart';

void main() {
  late FakeAiRepository repo;
  late FakeHistory history;
  late FakeCrashReporter crash;
  late ProviderContainer container;

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: chatOverrides(repo: repo, history: history, crash: crash),
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

  test('streams cards, batches text deltas, then stores the answer', () async {
    await container.read(chatControllerProvider.future);
    controller().ask('  Explain theta  ');
    expect(state().answers.single.question, 'Explain theta');
    expect(state().answers.single.status, AnswerStatus.sending);
    expect(history.all.single.status, AnswerStatus.sending);

    repo.last
      ..add(
        AnswerStarted(
          answerId: 'x',
          intent: 'explain',
          serverTime: DateTime(2026),
        ),
      )
      ..add(CardAdded(textCard('c')))
      ..add(const TextDelta(cardId: 'c', text: 'Time'))
      ..add(const TextDelta(cardId: 'c', text: ' decay'));
    await pumpEventQueue();
    expect(state().answers.single.status, AnswerStatus.streaming);
    expect(
      state().answers.single.cards.single.text,
      isEmpty,
      reason: 'deltas wait for the next flush',
    );

    await Future<void>.delayed(ChatController.flushEvery * 2);
    expect(state().answers.single.cards.single.text, 'Time decay');

    repo.last.add(
      const AnswerDone(
        cards: 1,
        topic: AskTopic(underlying: 'NIFTY'),
        chips: ['Explain IV'],
      ),
    );
    await pumpEventQueue();
    expect(state().answers.single.status, AnswerStatus.complete);
    expect(state().chips, ['Explain IV']);
    expect(state().topic, const AskTopic(underlying: 'NIFTY'));
    expect(history.all.single.status, AnswerStatus.complete);
  });

  test('five deltas in one flush window publish one state update', () async {
    await container.read(chatControllerProvider.future);
    controller().ask('Explain the move');
    repo.last.add(CardAdded(textCard('batched')));
    await pumpEventQueue();

    var updates = 0;
    final listener = container.listen(chatControllerProvider, (_, next) {
      if (next.value?.answers.single.cards.single.text.isNotEmpty ?? false) {
        updates++;
      }
    });
    for (final part in ['A', ' ', 'single', ' ', 'update']) {
      repo.last.add(TextDelta(cardId: 'batched', text: part));
    }
    await pumpEventQueue();
    expect(updates, 0, reason: 'deltas wait for their shared 50 ms flush');

    await Future<void>.delayed(
      ChatController.flushEvery + const Duration(milliseconds: 10),
    );
    expect(updates, 1);
    expect(state().answers.single.cards.single.text, 'A single update');
    listener.close();
  });

  test('a delta pending when the next card arrives is applied first', () async {
    await container.read(chatControllerProvider.future);
    controller().ask('Quote RELIANCE');
    repo.last
      ..add(CardAdded(textCard('c1')))
      ..add(const TextDelta(cardId: 'c1', text: 'First'))
      ..add(CardAdded(textCard('c2')));
    await pumpEventQueue();
    final cards = state().answers.single.cards;
    expect(cards.map((c) => c.text), ['First', '']);
    expect(state().outline.lastCards, 2);
  });

  test(
    'a stream failure keeps received cards and marks the answer failed',
    () async {
      await container.read(chatControllerProvider.future);
      controller().ask('Compare the setup');
      repo.last
        ..add(CardAdded(textCard('first', text: 'First result')))
        ..add(CardAdded(textCard('second', text: 'Second result')))
        ..addError(StateError('connection dropped'));
      await pumpEventQueue();

      final answer = state().answers.single;
      expect(answer.status, AnswerStatus.failed);
      expect(answer.cards.map((card) => card.text), [
        'First result',
        'Second result',
      ]);
    },
  );

  test('ask ignores blank and over-long questions', () async {
    await container.read(chatControllerProvider.future);
    controller()
      ..ask('   ')
      ..ask('x' * (ChatLimits.maxQuestion + 1));
    expect(state().answers, isEmpty);
    expect(repo.streams, isEmpty);
  });

  test('a new question stops the one still streaming', () async {
    await container.read(chatControllerProvider.future);
    controller()
      ..ask('One')
      ..ask('Two');
    expect(state().answers.map((a) => a.status), [
      AnswerStatus.stopped,
      AnswerStatus.sending,
    ]);
    repo.streams.first.add(CardAdded(textCard('late')));
    await pumpEventQueue();
    expect(state().answers.first.cards, isEmpty);
  });

  test('stopping after a card keeps the partial answer visible', () async {
    await container.read(chatControllerProvider.future);
    controller().ask('Explain the signal');
    repo.last.add(CardAdded(textCard('partial', text: 'Partial result')));
    await pumpEventQueue();

    await controller().stop();

    expect(state().answers.single.status, AnswerStatus.stopped);
    expect(state().answers.single.cards.single.text, 'Partial result');
  });

  test(
    'a stopped answer offers no retry; a failed one retries in place',
    () async {
      await container.read(chatControllerProvider.future);
      controller().ask('NIFTY');
      await controller().stop();
      final id = state().answers.single.id;
      expect(state().answers.single.status, AnswerStatus.stopped);
      controller().retry(id);
      expect(repo.streams, hasLength(1));

      controller().retry('missing');
      controller().ask('Again');
      await repo.last.close();
      await pumpEventQueue();
      final failed = state().answers.last;
      expect(failed.status, AnswerStatus.failed, reason: 'closed without done');

      controller().retry(failed.id);
      expect(repo.streams, hasLength(3));
      expect(state().answers.last.id, failed.id);
      expect(state().answers.last.status, AnswerStatus.sending);
    },
  );

  test('a failed answer keeps its error; retry clears it', () async {
    await container.read(chatControllerProvider.future);
    controller().ask('Quote RELIANCE');
    repo.last.add(CardAdded(textCard('before-failure')));
    const missing = ServerError(404, 'http_404', 'Answer unavailable');
    repo.last.add(const AnswerFailed(missing, retryable: true));
    await pumpEventQueue();
    final failed = state().answers.single;
    expect(failed.error, missing);
    controller().retry(failed.id);
    expect(state().answers.single.id, failed.id);
    expect(state().answers.single.error, isNull);
    expect(state().answers.single.cards, isEmpty);
  });

  test(
    'a non-retryable failure and a stream error both end as failed',
    () async {
      await container.read(chatControllerProvider.future);
      controller().ask('One');
      repo.last.add(
        const AnswerFailed(ServerError(200, 'bad', 'm'), retryable: false),
      );
      await pumpEventQueue();
      controller().retry(state().answers.single.id);
      expect(repo.streams, hasLength(1));

      controller().ask('Two');
      repo.last.addError(StateError('boom'));
      await pumpEventQueue();
      expect(state().answers.last.status, AnswerStatus.failed);
    },
  );
}
