import 'package:flutter/material.dart';
import 'package:stock_pulse/features/chart/domain/fib_levels.dart';

/// Paints retracement guides between two chart-space anchor points.
class FibPainter extends CustomPainter {
  const FibPainter({
    required this.start,
    required this.end,
    required this.color,
    required this.labelColor,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final textStyle = TextStyle(color: labelColor, fontSize: 10);
    for (final level in fibLevels(0, 1)) {
      final y = start.dy + (end.dy - start.dy) * level.ratio;
      canvas.drawLine(
        Offset(mathMin(start.dx, end.dx), y),
        Offset(mathMax(start.dx, end.dx), y),
        linePaint,
      );
      final painter = TextPainter(
        text: TextSpan(text: level.label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(mathMax(start.dx, end.dx) - painter.width, y + 2),
      );
    }
  }

  @override
  bool shouldRepaint(FibPainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.color != color ||
      oldDelegate.labelColor != labelColor;
}

double mathMin(double a, double b) => a < b ? a : b;
double mathMax(double a, double b) => a > b ? a : b;
