import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// The snackbar card: tone stripe and icon (meaning never by colour alone),
/// up to two lines of text, one text action and, for messages that stay
/// until dismissed, a close button.
class SpSnack extends StatelessWidget {
  const SpSnack({
    super.key,
    required this.message,
    required this.onAction,
    required this.onClose,
  });

  final FeedbackMessage message;
  final VoidCallback onAction;
  final VoidCallback onClose;

  static IconData iconOf(FeedbackKind kind) => switch (kind) {
    FeedbackKind.info => AppIcons.info,
    FeedbackKind.success => AppIcons.success,
    FeedbackKind.error => AppIcons.error,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c =
        theme.extension<SpColors>() ??
        (theme.brightness == Brightness.dark ? SpColors.dark : SpColors.light);
    final tone = switch (message.kind) {
      FeedbackKind.success => c.up,
      FeedbackKind.error => c.down,
      FeedbackKind.info => c.info,
    };
    final label = message.actionLabel;
    return Material(
      color: c.surface2,
      elevation: 8,
      shadowColor: c.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SpRadius.l),
        side: BorderSide(color: c.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(color: tone, child: const SizedBox(width: 4)),
            const SizedBox(width: SpSpace.s3),
            Center(
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: .16),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(iconOf(message.kind), size: 20, color: tone),
                  ),
                ),
              ),
            ),
            const SizedBox(width: SpSpace.s3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: SpSpace.s3),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    message.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            if (label != null && message.action != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: c.accent,
                  minimumSize: const Size(SpDensity.tap, SpDensity.tap),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: onAction,
                child: Text(label),
              ),
            if (message.persist)
              IconButton(
                tooltip: context.strings.common.dismiss,
                color: c.textSecondary,
                icon: const Icon(AppIcons.close),
                onPressed: onClose,
              )
            else
              const SizedBox(width: SpSpace.s2),
          ],
        ),
      ),
    );
  }
}
