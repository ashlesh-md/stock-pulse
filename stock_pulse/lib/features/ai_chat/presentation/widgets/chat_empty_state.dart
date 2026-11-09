import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// First open: a greeting and the suggested prompts as full-width rows.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key, required this.onPrompt});
  final ValueChanged<String> onPrompt;
  @override
  Widget build(BuildContext context) {
    final s = context.strings.chat;
    final sp = context.sp;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(SpSpace.gutter),
      children: [
        const SizedBox(height: SpSpace.s6),
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: sp.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(AppIcons.ai, color: sp.accent, size: 28),
          ),
        ),
        const SizedBox(height: SpSpace.s4),
        Text(s.emptyTitle, textAlign: TextAlign.center, style: text.titleLarge),
        const SizedBox(height: SpSpace.s2),
        Text(
          s.emptyMessage,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: sp.textSecondary),
        ),
        const SizedBox(height: SpSpace.s6),
        Text(
          s.tryAsking,
          style: text.labelLarge?.copyWith(color: sp.textSecondary),
        ),
        const SizedBox(height: SpSpace.s2),
        for (final prompt in s.suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: SpSpace.s2),
            child: Material(
              color: sp.surface1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SpRadius.m),
                side: BorderSide(color: sp.outline),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onPrompt(prompt),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: SpDensity.tap),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpSpace.s4,
                      vertical: SpSpace.s3,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(prompt, style: text.bodyMedium)),
                        Icon(
                          AppIcons.chevronRight,
                          size: 20,
                          color: sp.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
