import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// `⌛ Pending`: `info` on `infoTint`. Pending is neither a
/// failure nor a price warning, so it is never `down` or `warn`.
class PendingBadge extends StatelessWidget {
  const PendingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final sp = context.sp;
    final strings = context.strings.common;
    return Semantics(
      label: strings.orderPendingSemantics,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: sp.infoTint,
            borderRadius: BorderRadius.circular(SpRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpSpace.s2,
              vertical: 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.pending, size: 12, color: sp.info),
                const SizedBox(width: SpSpace.s1),
                Text(
                  strings.pending,
                  style: context.spText.caption.copyWith(color: sp.info),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
