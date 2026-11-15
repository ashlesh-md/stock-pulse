import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/drawing_geometry.dart';
import 'package:stock_pulse/features/chart/presentation/chart_paint_text.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/fib_painter.dart';

class DrawingPainter extends CustomPainter {
  const DrawingPainter({
    required this.drawing,
    required this.geometry,
    required this.color,
    required this.labelColor,
  });
  final Drawing drawing;
  final DrawingGeometry geometry;
  final Color color;
  final Color labelColor;
  Offset point(DrawingAnchor a) {
    final (x, y) = geometry.project(a);
    return Offset(x, y);
  }

  (Offset, Offset) get ends => drawing.kind == DrawingKind.horizontal
      ? (
          Offset(0, point(drawing.start).dy),
          Offset(geometry.width, point(drawing.start).dy),
        )
      : (point(drawing.start), point(drawing.end ?? drawing.start));

  @override
  void paint(Canvas canvas, Size size) {
    final (a, b) = ends;
    if (drawing.kind == DrawingKind.fibRetracement) {
      FibPainter(
        start: a,
        end: b,
        color: color,
        labelColor: labelColor,
      ).paint(canvas, size);
      return;
    }
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = 1.5,
    );
    if (drawing.kind == DrawingKind.horizontal) {
      paintChartLabel(
        canvas,
        TextStyle(color: labelColor, fontSize: 11),
        Fmt.price(drawing.start.price),
        Offset(geometry.width, a.dy - 10),
        color,
        labelColor,
      );
    }
  }

  @override
  bool hitTest(Offset position) {
    final (a, b) = ends;
    final delta = b - a;
    final length = delta.distanceSquared;
    final t = length == 0
        ? 0.0
        : ((position - a).dx * delta.dx + (position - a).dy * delta.dy) /
              length;
    final nearest = a + delta * t.clamp(0, 1);
    return (nearest - position).distance <= math.max(22, 1.5);
  }

  @override
  bool shouldRepaint(DrawingPainter old) =>
      old.drawing != drawing ||
      old.geometry != geometry ||
      old.color != color ||
      old.labelColor != labelColor;
}
