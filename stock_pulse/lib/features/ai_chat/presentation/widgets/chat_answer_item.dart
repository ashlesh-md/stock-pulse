import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/observability/perf_marks.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_providers.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_answer_view.dart';

/// One list row. It watches only its own answer, so streaming text rebuilds
/// the newest row and nothing else.
class ChatAnswerItem extends ConsumerStatefulWidget {
  const ChatAnswerItem({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ChatAnswerItem> createState() => _ChatAnswerItemState();
}

class _ChatAnswerItemState extends ConsumerState<ChatAnswerItem> {
  bool _firstCardMarkScheduled = false;
  bool _streamDoneMarked = false;

  @override
  Widget build(BuildContext context) {
    final answer = ref.watch(
      chatControllerProvider.select((s) => s.value?.answer(widget.id)),
    );
    if (answer == null) return const SizedBox.shrink();
    if (answer.cards.isNotEmpty && !_firstCardMarkScheduled) {
      _firstCardMarkScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) PerfMarks.mark('ai_first_card_painted');
      });
    }
    if (answer.status == AnswerStatus.complete && !_streamDoneMarked) {
      _streamDoneMarked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) PerfMarks.mark('ai_stream_done');
      });
    }
    final controller = ref.read(chatControllerProvider.notifier);
    return ChatAnswerView(
      answer: answer,
      onRetry: () => controller.retry(widget.id),
      onExplain: controller.ask,
    );
  }
}
