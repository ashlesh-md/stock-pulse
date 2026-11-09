import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';

/// Which way the last price change went.
enum TickDirection { up, down, none }

/// A price. Text is `textPrimary`; for
/// 1.5 s after the last change it takes the `up`/`down` colour, computed at
/// build from [lastTickAt] against server time, so there is no timer: the
/// next tick or freshness flip repaints it. Stale is `textTertiary`.
class SpPriceCell extends ConsumerWidget {
  const SpPriceCell({
    super.key,
    required this.value,
    required this.text,
    this.lastTickAt,
    this.lastDirection = TickDirection.none,
    this.isStale = false,
    this.dense = false,
    this.style,
    this.textAlign = TextAlign.right,
  });

  /// Direction colour lasts this long after [lastTickAt].
  static const tintFor = Duration(milliseconds: 1500);

  final double? value;

  /// Formatted value; ignored (shows `—`) when [value] is null.
  final String text;

  /// Server time of the last price change.
  final DateTime? lastTickAt;
  final TickDirection lastDirection;
  final bool isStale;

  /// `priceDense` instead of `price`.
  final bool dense;

  /// Overrides the base text style (size only; colour is always a token).
  final TextStyle? style;

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = context.sp;
    final strings = context.strings.common;
    final base =
        style ?? (dense ? context.spText.priceDense : context.spText.price);
    final tick = lastTickAt;
    final recent =
        tick != null &&
        lastDirection != TickDirection.none &&
        ref.watch(serverClockProvider).now().difference(tick) < tintFor;
    final color = isStale
        ? sp.textTertiary
        : !recent
        ? sp.textPrimary
        : lastDirection == TickDirection.up
        ? sp.up
        : sp.down;
    final shown = value == null ? strings.noValue : text;
    final dir = switch (lastDirection) {
      TickDirection.up when recent => strings.priceUp,
      TickDirection.down when recent => strings.priceDown,
      _ => '',
    };
    return Semantics(
      label: value == null
          ? strings.priceUnavailable
          : strings.priceSemantics(
              shown.replaceAll('₹', ''),
              direction: dir,
              stale: isStale,
            ),
      child: ExcludeSemantics(
        child: Text(
          shown,
          textAlign: textAlign,
          maxLines: 1,
          style: base.copyWith(
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
