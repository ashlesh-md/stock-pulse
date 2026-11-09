import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/strategy/application/payoff_geometry.dart';
import 'package:stock_pulse/features/strategy/presentation/widgets/payoff_painter.dart';

class PayoffChart extends StatefulWidget {
  const PayoffChart({
    super.key,
    required this.geometry,
    required this.summary,
    this.compact = false,
  });
  final PayoffGeometry geometry;
  final String summary;
  final bool compact;
  @override
  State<PayoffChart> createState() => _PayoffChartState();
}

class _PayoffChartState extends State<PayoffChart> {
  final _crosshair = ValueNotifier<double?>(null);
  @override
  void dispose() {
    _crosshair.dispose();
    super.dispose();
  }

  void _set(double localX, double width) {
    final g = widget.geometry;
    final fraction = ((localX - 36) / math.max(1, width - 48)).clamp(0.0, 1.0);
    final index = (fraction * (g.x.length - 1)).round();
    final old = _crosshair.value;
    if (old != null) {
      final previous = (old * (g.x.length - 1)).round();
      if (g.expiry[previous] * g.expiry[index] < 0) {
        HapticFeedback.selectionClick().ignore();
      }
    }
    _crosshair.value = fraction;
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.geometry;
    final sp = context.sp;
    return Semantics(
      label: '${context.strings.strategy.chart}. ${widget.summary}',
      child: SizedBox(
        height: widget.compact ? 140 : 240,
        child: LayoutBuilder(
          builder: (context, bounds) => GestureDetector(
            onHorizontalDragStart: widget.compact
                ? null
                : (d) => _set(d.localPosition.dx, bounds.maxWidth),
            onHorizontalDragUpdate: widget.compact
                ? null
                : (d) => _set(d.localPosition.dx, bounds.maxWidth),
            onTapUp: widget.compact
                ? null
                : (d) => _set(d.localPosition.dx, bounds.maxWidth),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: PayoffPainter(
                      g,
                      line: sp.textPrimary,
                      up: sp.up,
                      down: sp.down,
                      today: sp.info,
                      axis: sp.outline,
                    ),
                  ),
                ),
                if (!widget.compact)
                  CustomPaint(
                    painter: PayoffCrosshairPainter(g, _crosshair, sp.accent),
                  ),
                if (!widget.compact)
                  ValueListenableBuilder<double?>(
                    valueListenable: _crosshair,
                    builder: (context, fraction, _) {
                      if (fraction == null) return const SizedBox.shrink();
                      final i = (fraction * (g.x.length - 1)).round();
                      final label = context.strings.strategy.crosshair(
                        Fmt.price(g.x[i]),
                        Fmt.price(g.expiry[i]),
                      );
                      final style = Theme.of(context).textTheme.bodyMedium;
                      final tooltipWidth = math.min(
                        bounds.maxWidth - 16,
                        220.0,
                      );
                      final crosshairX = 36 + fraction * (bounds.maxWidth - 48);
                      final left = (crosshairX - tooltipWidth / 2)
                          .clamp(8, bounds.maxWidth - tooltipWidth - 8)
                          .toDouble();
                      return Positioned(
                        left: left,
                        top: 0,
                        child: SizedBox(
                          width: tooltipWidth,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: sp.surface2,
                            child: Text(label, style: style, maxLines: 2),
                          ),
                        ),
                      );
                    },
                  ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    Fmt.price(g.xMin),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    Fmt.price(g.xMax),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
