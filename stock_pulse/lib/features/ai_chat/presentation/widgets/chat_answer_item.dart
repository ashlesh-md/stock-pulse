import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_providers.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_answer_view.dart';

/// One list row. It watches only its own answer, so streaming text rebuilds
/// the newest row and nothing else.
class ChatAnswerItem extends ConsumerWidget {
  const ChatAnswerItem({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answer = ref.watch(
      chatControllerProvider.select((s) => s.value?.answer(id)),
    );
    if (answer == null) return const SizedBox.shrink();
    final controller = ref.read(chatControllerProvider.notifier);
    return ChatAnswerView(
      answer: answer,
      onRetry: () => controller.retry(id),
      onExplain: controller.ask,
    );
  }
}
