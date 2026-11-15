import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/drawing_geometry.dart';
import 'package:stock_pulse/features/chart/domain/tick_snap.dart';

void main() {
  test('S-55 time and price anchors survive viewport changes', () {
    final time = DateTime.utc(2026);
    final geometry = DrawingGeometry(
      first: time,
      last: time.add(const Duration(days: 1)),
      low: 100,
      high: 200,
      width: 300,
      height: 200,
    );
    final anchor = DrawingAnchor(
      time: time.add(const Duration(hours: 12)),
      price: 150,
    );
    expect(geometry.project(anchor), (150, 100));
    expect(geometry.unproject(150, 100), anchor);
    expect(geometry.timeDelta(150), const Duration(hours: 12));
    expect(geometry.priceDelta(20), -10);
    expect(snapToTick(1500.02, .05), 1500);
    expect(() => snapToTick(1, 0), throwsArgumentError);
    expect(() => snapToTick(double.nan, .05), throwsArgumentError);
  });
}
