import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// `⏱ Stale since 10:42:07`. Shows the fixed as-of time, never a
/// running age, so it does not repaint every second.
class StaleBadge extends StatelessWidget {
  /// Inline pill (rows, ticket header).
  const StaleBadge({super.key, required this.asOf}) : banner = false;

  /// Full-width 36 dp feed banner: `Prices not live since 10:42:07`.
  const StaleBadge.banner({super.key, required this.asOf}) : banner = true;

  /// Device-local time shown; null = never confirmed.
  final DateTime? asOf;
  final bool banner;

  @override
  Widget build(BuildContext context) {
    final sp = context.sp;
    final strings = context.strings.common;
    final at = asOf;
    final text = switch ((banner, at)) {
      (true, null) => strings.pricesNotLive,
      (true, final t?) => strings.pricesNotLiveSince(Fmt.time(t)),
      (false, null) => strings.stale,
      (false, final t?) => strings.staleSince(Fmt.time(t)),
    };
    final style = context.spText.caption.copyWith(color: sp.warn);
    final content = Row(
      mainAxisSize: banner ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(AppIcons.time, size: banner ? 16 : 12, color: sp.warn),
        const SizedBox(width: SpSpace.s1),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
    if (banner) {
      return Semantics(
        liveRegion: true,
        label: text,
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            width: double.infinity,
            color: sp.warnTint,
            padding: const EdgeInsets.symmetric(horizontal: SpSpace.gutter),
            alignment: Alignment.centerLeft,
            child: content,
          ),
        ),
      );
    }
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: sp.warnTint,
            borderRadius: BorderRadius.circular(SpRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpSpace.s2,
              vertical: 2,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
