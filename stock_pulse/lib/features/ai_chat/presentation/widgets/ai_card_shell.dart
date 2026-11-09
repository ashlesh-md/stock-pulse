import 'package:flutter/material.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// Frame of every answer card: header (icon, type, optional trailing such as
/// "as of"), a 2 dp progress rule while the card streams, the body, action
/// buttons and the permanent disclaimer.
class AiCardShell extends StatelessWidget {
  const AiCardShell({
    super.key,
    required this.icon,
    required this.label,
    required this.child,
    this.trailing,
    this.streaming = false,
    this.actions = const [],
  });
  final IconData icon;
  final String label;
  final Widget? trailing;
  final bool streaming;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final sp = context.sp;
    return Container(
      margin: const EdgeInsets.only(bottom: SpSpace.s2),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: sp.surface1,
        borderRadius: BorderRadius.circular(SpRadius.m),
        border: Border.all(color: sp.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 2,
            child: streaming
                ? LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: sp.surface0.withValues(alpha: 0),
                    color: sp.accent,
                    semanticsLabel: context.strings.chat.writing,
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SpSpace.s3,
              SpSpace.s2,
              SpSpace.s3,
              SpSpace.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: sp.accent),
                    const SizedBox(width: SpSpace.s2),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: SpSpace.s2),
                if (streaming)
                  child
                else
                  AnimatedSize(
                    duration: const Duration(milliseconds: 120),
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: SpSpace.s1),
                    child: Wrap(spacing: SpSpace.s1, children: actions),
                  ),
                const SizedBox(height: SpSpace.s2),
                Text(
                  context.strings.chat.disclaimer,
                  style: context.spText.caption.copyWith(
                    color: sp.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
