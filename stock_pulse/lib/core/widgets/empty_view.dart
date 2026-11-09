import 'package:flutter/material.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/core/widgets/error_view.dart' show ErrorView;

/// Centered empty state: icon, title, one-line reason, optional
/// primary action. Max width 320.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Small extra line (debug-only server hint in [ErrorView]).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final sp = context.sp;
    final text = Theme.of(context).textTheme;
    final label = actionLabel;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(SpSpace.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: sp.textTertiary),
              const SizedBox(height: SpSpace.s3),
              Text(title, textAlign: TextAlign.center, style: text.titleMedium),
              const SizedBox(height: SpSpace.s1),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: sp.textSecondary),
              ),
              if (hint case final h?) ...[
                const SizedBox(height: SpSpace.s1),
                Text(
                  h,
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: sp.textTertiary),
                ),
              ],
              if (label != null && onAction != null) ...[
                const SizedBox(height: SpSpace.s4),
                FilledButton(onPressed: onAction, child: Text(label)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
