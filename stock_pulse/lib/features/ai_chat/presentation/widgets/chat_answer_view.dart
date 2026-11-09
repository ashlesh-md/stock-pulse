import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/l10n/strings/error_strings.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_view.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/appear_in.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/attachment_preview.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/typing_indicator.dart';

/// One exchange: the question bubble (right), its attachments, the answer
/// cards (left, each grows in as it arrives), a typing row until the first
/// card, and a closing row when the answer failed or was stopped. Retry is
/// offered on a failed answer only.
class ChatAnswerView extends StatelessWidget {
  const ChatAnswerView({
    super.key,
    required this.answer,
    required this.onRetry,
    required this.onExplain,
  });
  final ChatAnswer answer;
  final VoidCallback onRetry;
  final ValueChanged<String> onExplain;

  @override
  Widget build(BuildContext context) {
    final cards = answer.cards;
    return Padding(
      padding: const EdgeInsets.only(bottom: SpSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuestionBubble(answer: answer),
          if (answer.attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: SpSpace.s1),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: SpSpace.s1,
                runSpacing: SpSpace.s1,
                children: [
                  for (final attachment in answer.attachments)
                    AttachmentPreview(attachment: attachment),
                ],
              ),
            ),
          if (answer.status == AnswerStatus.sending)
            _caption(context, context.strings.chat.sending, TextAlign.end),
          const SizedBox(height: SpSpace.s3),
          for (final (i, card) in cards.indexed)
            AppearIn(
              key: ValueKey(card.id),
              animate: answer.busy,
              child: AiCardView(
                card: card,
                onExplain: onExplain,
                streaming: answer.busy && i == cards.length - 1,
              ),
            ),
          if (answer.busy && cards.isEmpty) const _ThinkingRow(),
          if (answer.status == AnswerStatus.failed)
            _FailedRow(answer: answer, onRetry: onRetry),
          if (answer.status == AnswerStatus.stopped)
            _caption(context, context.strings.chat.stopped, TextAlign.start),
        ],
      ),
    );
  }

  Widget _caption(BuildContext context, String text, TextAlign align) =>
      Padding(
        padding: const EdgeInsets.only(top: SpSpace.s1),
        child: Text(
          text,
          textAlign: align,
          style: context.spText.caption.copyWith(
            color: context.sp.textTertiary,
          ),
        ),
      );
}

class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({required this.answer});
  final ChatAnswer answer;
  @override
  Widget build(BuildContext context) {
    final sp = context.sp;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.8,
        alignment: Alignment.centerRight,
        child: Align(
          alignment: Alignment.centerRight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: sp.accent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(SpRadius.l),
                topRight: Radius.circular(SpRadius.l),
                bottomLeft: Radius.circular(SpRadius.l),
                bottomRight: Radius.circular(SpRadius.s),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpSpace.s4,
                vertical: SpSpace.s3,
              ),
              child: SelectableText(
                answer.question,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: sp.onAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();
  @override
  Widget build(BuildContext context) {
    final s = context.strings.chat;
    final sp = context.sp;
    return Semantics(
      liveRegion: true,
      label: s.thinking,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: SpSpace.s2),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SpSpace.s3,
            vertical: SpSpace.s3,
          ),
          decoration: BoxDecoration(
            color: sp.surface1,
            borderRadius: BorderRadius.circular(SpRadius.l),
            border: Border.all(color: sp.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.ai, size: 16, color: sp.accent),
              const SizedBox(width: SpSpace.s2),
              ExcludeSemantics(
                child: Text(
                  s.thinking,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: sp.textSecondary),
                ),
              ),
              const SizedBox(width: SpSpace.s2),
              const TypingIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.answer, required this.onRetry});
  final ChatAnswer answer;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final error = answer.error;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(top: SpSpace.s1),
        padding: const EdgeInsets.fromLTRB(SpSpace.s3, 0, 0, 0),
        constraints: const BoxConstraints(minHeight: SpDensity.tap),
        decoration: BoxDecoration(
          color: context.sp.surface1,
          borderRadius: BorderRadius.circular(SpRadius.m),
          border: Border.all(color: scheme.error.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Icon(AppIcons.error, size: 18, color: scheme.error),
            const SizedBox(width: SpSpace.s2),
            Expanded(
              child: Text(
                error == null
                    ? strings.chat.failed
                    : errorText(strings.errors, error),
              ),
            ),
            if (answer.retryable)
              TextButton(onPressed: onRetry, child: Text(strings.chat.retry)),
          ],
        ),
      ),
    );
  }
}
