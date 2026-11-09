import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stock_pulse/features/strategy/application/payoff_geometry.dart';

class PayoffPainter extends CustomPainter {
  PayoffPainter(
    this.geometry, {
    required this.line,
    required this.up,
    required this.down,
    required this.today,
    required this.axis,
  });
  final PayoffGeometry geometry;
  final Color line, up, down, today, axis;
  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final plot = Rect.fromLTRB(36, 28, size.width - 12, size.height - 24);
    if (plot.isEmpty) return;
    double x(double value) =>
        plot.left + (value - g.xMin) / (g.xMax - g.xMin) * plot.width;
    double y(double value) =>
        plot.bottom - (value - g.yMin) / (g.yMax - g.yMin) * plot.height;
    final path = Path()..moveTo(x(g.x.first), y(g.expiry.first));
    for (var i = 1; i < g.x.length; i++) {
      path.lineTo(x(g.x[i]), y(g.expiry[i]));
    }
    final fill = Path.from(path)
      ..lineTo(x(g.x.last), y(0))
      ..lineTo(x(g.x.first), y(0))
      ..close();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plot.left, plot.top, plot.right, y(0)));
    canvas.drawPath(fill, Paint()..color = up.withValues(alpha: .15));
    canvas.restore();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plot.left, y(0), plot.right, plot.bottom));
    canvas.drawPath(fill, Paint()..color = down.withValues(alpha: .15));
    canvas.restore();
    canvas.drawLine(
      Offset(plot.left, y(0)),
      Offset(plot.right, y(0)),
      Paint()..color = axis,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (g.today case final values?) {
      final todayPath = Path()..moveTo(x(g.x.first), y(values.first));
      for (var i = 1; i < g.x.length; i++) {
        todayPath.lineTo(x(g.x[i]), y(values[i]));
      }
      canvas.drawPath(
        todayPath,
        Paint()
          ..color = today
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    if (g.spot case final spot?) {
      canvas.drawLine(
        Offset(x(spot), plot.top),
        Offset(x(spot), plot.bottom),
        Paint()..color = axis,
      );
    }
  }

  @override
  bool shouldRepaint(PayoffPainter old) =>
      old.geometry != geometry ||
      old.line != line ||
      old.up != up ||
      old.down != down ||
      old.today != today ||
      old.axis != axis;
}

class PayoffCrosshairPainter extends CustomPainter {
  PayoffCrosshairPainter(this.geometry, this.crosshair, this.color)
    : super(repaint: crosshair);
  final PayoffGeometry geometry;
  final ValueListenable<double?> crosshair;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final fraction = crosshair.value;
    if (fraction == null) return;
    final dx = 36 + fraction * (size.width - 48);
    canvas.drawLine(
      Offset(dx, 28),
      Offset(dx, size.height - 24),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(PayoffCrosshairPainter old) =>
      old.geometry != geometry || old.color != color;
}
