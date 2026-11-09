import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';

/// "↓ New answer", slid in while [visible].
class NewAnswerPill extends StatelessWidget {
  const NewAnswerPill({super.key, required this.visible, required this.onTap});
  final ValueListenable<bool> visible;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: visible,
    builder: (context, shown, _) => IgnorePointer(
      ignoring: !shown,
      child: AnimatedSlide(
        offset: shown ? Offset.zero : const Offset(0, 0.6),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: ExcludeSemantics(
            excluding: !shown,
            child: FilledButton.tonalIcon(
              onPressed: onTap,
              icon: const Icon(AppIcons.scrollToLatest, size: 18),
              label: Text(context.strings.chat.newAnswer),
            ),
          ),
        ),
      ),
    ),
  );
}
