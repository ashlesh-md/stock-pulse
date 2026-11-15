import 'package:flutter/material.dart';

void paintChartText(
  Canvas canvas,
  TextStyle textStyle,
  String text,
  Offset at,
) {
  (TextPainter(
    text: TextSpan(text: text, style: textStyle),
    textDirection: TextDirection.ltr,
  )..layout()).paint(canvas, at);
}

void paintChartLabel(
  Canvas canvas,
  TextStyle textStyle,
  String text,
  Offset at,
  Color background,
  Color foreground,
) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: textStyle.copyWith(color: foreground),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(at.dx, at.dy, tp.width + 8, tp.height + 4),
      const Radius.circular(3),
    ),
    Paint()..color = background,
  );
  tp.paint(canvas, at + const Offset(4, 2));
}
