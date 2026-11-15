import 'package:flutter/material.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/widgets/stale_badge.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

/// Compact OHLCV readout for the crosshair candle, or the latest candle.
class ReadoutRow extends StatelessWidget {
  const ReadoutRow({
    super.key,
    required this.candle,
    this.previousClose,
    this.staleSince,
    this.staleBadge,
  });

  final Candle? candle;
  final double? previousClose;
  final DateTime? staleSince;
  final Widget? staleBadge;

  @override
  Widget build(BuildContext context) {
    final item = candle;
    final badge = staleBadge;
    if (item == null) return const SizedBox(height: 24);
    final denominator = previousClose ?? item.open;
    final change = item.close - denominator;
    final percent = denominator == 0 ? 0.0 : change / denominator * 100;
    final sp = context.sp;
    final labelStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: sp.textTertiary);
    final valueStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: sp.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget value(String label, String value, {Color? color}) => RichText(
      maxLines: 1,
      text: TextSpan(
        children: [
          TextSpan(text: '$label ', style: labelStyle),
          TextSpan(
            text: value,
            style: valueStyle?.copyWith(color: color),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          value('O', Fmt.price(item.open)),
          value('H', Fmt.price(item.high)),
          value('L', Fmt.price(item.low)),
          value('C', Fmt.price(item.close)),
          value('V', Fmt.compact(item.volume)),
          value(
            'Δ',
            '${Fmt.signed(change)} (${Fmt.percent(percent)})',
            color: sp.directionOf(change),
          ),
          ?badge,
          if (badge == null && staleSince != null) StaleBadge(asOf: staleSince),
        ],
      ),
    );
  }
}
