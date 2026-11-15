import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/domain/chart_layout.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';

void main() {
  test('two drawings and two studies round-trip with value equality', () {
    final layout = ChartLayout(
      drawings: [
        Drawing(
          id: 'horizontal-1',
          kind: DrawingKind.horizontal,
          start: DrawingAnchor(time: DateTime.utc(2026, 11, 9), price: 1500),
        ),
        Drawing(
          id: 'trend-1',
          kind: DrawingKind.trendLine,
          start: DrawingAnchor(time: DateTime.utc(2026, 11, 8), price: 1490),
          end: DrawingAnchor(time: DateTime.utc(2026, 11, 9), price: 1510),
        ),
      ],
      studies: const [
        StudySpec(kind: StudyKind.rsi),
        StudySpec(kind: StudyKind.sma, period: 20),
      ],
    );

    final restored = ChartLayout.fromJson(layout.toJson());
    expect(restored, layout);
    expect(restored.hashCode, layout.hashCode);
  });

  test('rejects layouts written by an unsupported schema', () {
    expect(
      () => ChartLayout.fromJson({'schemaVersion': 2}),
      throwsFormatException,
    );
  });
}
