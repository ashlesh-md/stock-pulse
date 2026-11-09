import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/domain/fib_levels.dart';

void main() {
  test('Fibonacci retracement levels interpolate expected prices', () {
    final levels = fibLevels(100, 200);

    expect(fibToolReady, isTrue);
    expect(levels.map((level) => level.ratio), [0, .236, .382, .5, .618, 1]);
    expect(levels.map((level) => level.price), [
      100,
      123.6,
      138.2,
      150,
      161.8,
      200,
    ]);
    expect(levels[4].price, closeTo(161.8, 1e-10));
  });

  test('Fib levels support reverse direction anchors', () {
    expect(fibLevels(200, 100)[4].price, closeTo(138.2, 1e-10));
  });
}
