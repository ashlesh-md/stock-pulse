import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_painter.dart';

void main() {
  test('study painter handles gaps, histogram, and invalid bounds safely', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    StudyPainter(
      lines: [
        [1, null, 2, 3],
        [-1, 0, 1, null],
      ],
      start: 0,
      end: 10,
      width: 8,
      low: -2,
      high: 4,
      colors: const [Colors.blue, Colors.red],
      histogram: true,
    ).paint(canvas, const Size(80, 40));
    StudyPainter(
      lines: [
        [1, 2],
      ],
      start: 0,
      end: 2,
      width: 8,
      low: 1,
      high: 1,
      colors: const [Colors.blue],
      priceOverlay: true,
    ).paint(canvas, const Size(80, 40));
    recorder.endRecording().dispose();
  });

  test('study painter repaints when the plotted series changes', () {
    StudyPainter painter({required List<double?> values, int end = 2}) =>
        StudyPainter(
          lines: [values],
          start: 0,
          end: end,
          width: 1,
          low: 0,
          high: 3,
          colors: const [Colors.blue],
        );

    final baseline = painter(values: const [1, 2]);
    expect(painter(values: const [1, 3]).shouldRepaint(baseline), isTrue);
    expect(painter(values: const [1, 2]).shouldRepaint(baseline), isFalse);
    expect(
      painter(values: const [1, 2], end: 1).shouldRepaint(baseline),
      isTrue,
    );
    expect(
      StudyPainter(
        lines: const [
          <double?>[1, 2],
        ],
        start: 0,
        end: 2,
        width: 1,
        low: 0,
        high: 3,
        colors: const [Colors.blue],
        histogram: true,
      ).shouldRepaint(baseline),
      isTrue,
    );
  });
}
