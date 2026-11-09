import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/fib_painter.dart';

void main() {
  const painter = FibPainter(
    start: Offset(10, 10),
    end: Offset(200, 120),
    color: Colors.white,
    labelColor: Colors.grey,
  );

  test('paints one guide per level and repaints only on change', () {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(240, 160));
    expect(recorder.endRecording(), isNotNull);
    expect(painter.shouldRepaint(painter), isFalse);
    expect(
      painter.shouldRepaint(
        const FibPainter(
          start: Offset(10, 10),
          end: Offset(200, 140),
          color: Colors.white,
          labelColor: Colors.grey,
        ),
      ),
      isTrue,
    );
  });

  test('min and max pick the right side', () {
    expect(mathMin(1, 2), 1);
    expect(mathMax(1, 2), 2);
  });
}
