import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class StudyPainter extends CustomPainter {
  StudyPainter({
    required this.lines,
    required this.start,
    required this.end,
    required this.width,
    required this.low,
    required this.high,
    required this.colors,
    this.priceOverlay = false,
    this.histogram = false,
    this.guides = const [],
  });
  final List<List<double?>> lines;
  final int start, end;
  final double width, low, high;
  final List<Color> colors;
  final bool priceOverlay, histogram;
  final List<double> guides;
  @override
  void paint(Canvas canvas, Size size) {
    final height = priceOverlay ? (size.height - 16) * .8 : size.height;
    final plotWidth = priceOverlay ? size.width - 64 : size.width;
    if (high <= low || height <= 0 || plotWidth <= 0) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, plotWidth, height));
    for (final guide in guides) {
      if (guide < low || guide > high) continue;
      final y = (high - guide) / (high - low) * height;
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(plotWidth, y),
        Paint()
          ..color = colors.first.withValues(alpha: .28)
          ..strokeWidth = 1,
      );
    }
    for (var j = 0; j < lines.length; j++) {
      final line = lines[j];
      final path = Path();
      var drawing = false;
      final paint = Paint()
        ..color = colors[j % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (var i = start; i < end && i < line.length; i++) {
        final value = line[i];
        if (value == null) {
          drawing = false;
          continue;
        }
        final dx = priceOverlay
            ? (i - start + .5) * width
            : (i - start + .5) / (end - start) * plotWidth;
        final dy = (high - value) / (high - low) * height;
        if (histogram && j == lines.length - 1) {
          final zero = (high) / (high - low) * height;
          canvas.drawLine(
            Offset(dx, zero),
            Offset(dx, dy),
            paint..strokeWidth = 2,
          );
        } else {
          if (drawing) {
            path.lineTo(dx, dy);
          } else {
            path.moveTo(dx, dy);
            drawing = true;
          }
        }
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StudyPainter old) =>
      !_sameLines(old.lines, lines) ||
      old.start != start ||
      old.end != end ||
      old.width != width ||
      old.low != low ||
      old.high != high ||
      !listEquals(old.colors, colors) ||
      old.priceOverlay != priceOverlay ||
      old.histogram != histogram ||
      !listEquals(old.guides, guides);

  bool _sameLines(List<List<double?>> left, List<List<double?>> right) =>
      left.length == right.length &&
      List.generate(
        left.length,
        (index) => listEquals(left[index], right[index]),
      ).every((same) => same);
}
