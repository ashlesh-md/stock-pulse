import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/market/presentation/widgets/candle_geometry.dart';

void main() {
  test('zoom preserves the candle under the focal point', () {
    final offset = CandleGeometry.anchoredOffset(
      1000,
      600,
      oldWidth: 5,
      newWidth: 10,
      offset: 20,
      focalX: 200,
    );
    const before = 1000 - 20 - (600 - 200) / 5;
    final after = 1000 - offset - (600 - 200) / 10;
    expect(after, closeTo(before, .00001));
  });
  test('zoom clamps to the available history at either edge', () {
    expect(
      CandleGeometry.anchoredOffset(
        10,
        600,
        oldWidth: 5,
        newWidth: 10,
        offset: 0,
        focalX: 0,
      ),
      0,
    );
    expect(
      CandleGeometry.anchoredOffset(
        100,
        200,
        oldWidth: 10,
        newWidth: 2,
        offset: 80,
        focalX: 0,
      ),
      0,
    );
  });
}
