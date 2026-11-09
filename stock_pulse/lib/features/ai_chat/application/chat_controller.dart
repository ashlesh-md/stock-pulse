import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/ai_chat/application/chat_state.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_data_providers.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';
import 'package:stock_pulse/features/ai_chat/domain/attachment_pick.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_attachment.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_limits.dart';

class ChatController extends AsyncNotifier<ChatState> {
  /// Streamed text is applied at most this often, so a burst of deltas costs
  /// one rebuild and the text grows in even steps.
  static const flushEvery = Duration(milliseconds: 50);

  StreamSubscription<AiEvent>? _subscription;
  Timer? _flushTimer;
  final _pending = <String, String>{};
  int _generation = 0;
  String? _activeId;
  int _sequence = 0;

  @override
  Future<ChatState> build() async {
    ref.onDispose(() {
      _generation++;
      _flushTimer?.cancel();
      unawaited(_subscription?.cancel());
    });
    try {
      final page = await ref
          .watch(chatHistoryProvider)
          .read(limit: ChatLimits.pageSize);
      return ChatState(answers: page.answers, hasOlder: page.hasMore);
    } on Exception {
      return ChatState(historyFailed: true);
    }
  }

  void ask(String question, {List<ChatAttachment> attachments = const []}) {
    final text = question.trim();
    if (text.isEmpty ||
        text.length > ChatLimits.maxQuestion ||
        !state.hasValue) {
      return;
    }
    _interrupt();
    final now = DateTime.now().toUtc();
    final answer = ChatAnswer(
      id: '${now.microsecondsSinceEpoch}.${_sequence++}',
      question: text,
      createdAt: now,
      attachments: attachments,
    );
    final answers = [...state.requireValue.answers, answer];
    if (answers.length > ChatLimits.maxAnswers) {
      answers.removeRange(0, answers.length - ChatLimits.maxAnswers);
    }
    _set(state.requireValue.copyWith(answers: answers));
    _start(answer);
  }

  /// Asks a failed answer's question again in place.
  void retry(String id) {
    final answer = state.value?.answer(id);
    if (answer == null ||
        answer.status != AnswerStatus.failed ||
        !answer.retryable) {
      return;
    }
    _interrupt();
    final fresh = answer.copyWith(
      status: AnswerStatus.sending,
      cards: [],
      error: null,
    );
    _replace(fresh);
    _start(fresh);
  }

  Future<void> loadOlder() async {
    final current = state.value;
    if (current == null ||
        !current.hasOlder ||
        current.loadingOlder ||
        current.answers.isEmpty) {
      return;
    }
    _set(current.copyWith(loadingOlder: true));
    try {
      final page = await ref
          .read(chatHistoryProvider)
          .read(beforeId: current.answers.first.id, limit: ChatLimits.pageSize);
      if (!ref.mounted) return;
      final combined = [...page.answers, ...state.requireValue.answers];
      final dropped = combined.length > ChatLimits.maxAnswers
          ? combined.length - ChatLimits.maxAnswers
          : 0;
      _set(
        state.requireValue.copyWith(
          answers: combined.skip(dropped).toList(growable: false),
          hasOlder: page.hasMore && dropped == 0,
          loadingOlder: false,
        ),
      );
    } on Exception {
      if (!ref.mounted) return;
      _set(state.requireValue.copyWith(hasOlder: false, loadingOlder: false));
    }
  }

  Future<AttachmentPick> pickAttachment() async {
    try {
      final file = await ref.read(attachmentPickerProvider)();
      if (file == null) return const AttachmentCancelled();
      if (file.size <= 0 || file.size > ChatLimits.maxAttachmentBytes) {
        return const AttachmentTooLarge();
      }
      return AttachmentPicked(
        ChatAttachment(name: file.name, size: file.size, bytes: file.bytes),
      );
    } on Exception {
      return const AttachmentFailed();
    }
  }

  Future<void> stop() async => _interrupt();

  void clear() {
    _interrupt();
    _set(ChatState());
    unawaited(_guard(ref.read(chatHistoryProvider).clear()));
  }

  void _start(ChatAnswer answer) {
    _activeId = answer.id;
    final generation = ++_generation;
    _subscription = ref
        .read(aiRepositoryProvider)
        .ask(answer.question, topic: state.requireValue.topic)
        .listen(
          (event) {
            if (ref.mounted && generation == _generation) _onEvent(event);
          },
          onError: (Object _) {
            if (ref.mounted && generation == _generation) {
              _finish(AnswerStatus.failed);
            }
          },
          onDone: () {
            if (ref.mounted &&
                generation == _generation &&
                (_activeAnswer?.busy ?? false)) {
              _finish(AnswerStatus.failed);
            }
          },
        );
    _persist(answer);
  }

  void _onEvent(AiEvent event) {
    final answer = _activeAnswer;
    if (answer == null || !answer.busy) return;
    switch (event) {
      case AnswerStarted(:final intent):
        ref.read(analyticsProvider).log(Events.aiQuestionAsked(intent));
        _replace(answer.copyWith(status: AnswerStatus.streaming));
      case CardAdded(:final card):
        _flush();
        final latest = _activeAnswer!;
        _replace(
          latest.copyWith(
            cards: [...latest.cards, card],
            status: AnswerStatus.streaming,
          ),
        );
      case TextDelta(:final cardId, :final text):
        _pending[cardId] = '${_pending[cardId] ?? ''}$text';
        _flushTimer ??= Timer(flushEvery, _flush);
      case AnswerDone(:final chips, :final topic):
        _set(state.requireValue.copyWith(chips: chips, topic: topic));
        _finish(AnswerStatus.complete);
      case AnswerFailed(:final error, :final retryable):
        _finish(AnswerStatus.failed, retryable: retryable, error: error);
    }
  }

  ChatAnswer? get _activeAnswer =>
      _activeId == null ? null : state.value?.answer(_activeId!);

  void _set(ChatState next) => state = AsyncData(next);

  void _replace(ChatAnswer answer) => _set(
    state.requireValue.copyWith(
      answers: [
        for (final a in state.requireValue.answers)
          a.id == answer.id ? answer : a,
      ],
    ),
  );

  void _flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final answer = _activeAnswer;
    if (answer != null && _pending.isNotEmpty) {
      _replace(
        answer.copyWith(
          cards: [
            for (final card in answer.cards)
              _pending.containsKey(card.id)
                  ? card.append(_pending[card.id]!)
                  : card,
          ],
        ),
      );
    }
    _pending.clear();
  }

  void _finish(AnswerStatus status, {bool retryable = true, AppError? error}) {
    _flush();
    final answer = _activeAnswer;
    if (answer == null) return;
    final done = answer.copyWith(
      status: status,
      retryable: retryable,
      error: error,
    );
    _replace(done);
    _persist(done);
  }

  void _interrupt() {
    _generation++;
    if (_activeAnswer?.busy ?? false) _finish(AnswerStatus.stopped);
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _persist(ChatAnswer answer) =>
      unawaited(_guard(ref.read(chatHistoryProvider).save(answer)));

  Future<void> _guard(Future<void> write) =>
      write.onError((Object error, StackTrace stack) {
        if (!ref.mounted) return;
        _set(state.requireValue.copyWith(historyFailed: true));
        ref
            .read(crashReporterProvider)
            .recordError(error, stack, reason: 'chat_history_write');
      });
}
