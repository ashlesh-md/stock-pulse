import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/data/backoff.dart';

void main() {
  test(
    'doubles each attempt, keeps between half and full delay, caps at max',
    () {
      final random = Random(1);
      for (final (attempt, full) in [
        (0, 500),
        (1, 1000),
        (2, 2000),
        (3, 4000),
        (10, 30000),
        (50, 30000),
      ]) {
        for (var i = 0; i < 50; i++) {
          final ms = reconnectDelay(attempt, random: random).inMilliseconds;
          expect(
            ms,
            inInclusiveRange(full ~/ 2, full),
            reason: 'attempt $attempt',
          );
        }
      }
    },
  );

  test('jitter spreads clients out', () {
    final random = Random(2);
    final delays = {
      for (var i = 0; i < 20; i++)
        reconnectDelay(4, random: random).inMilliseconds,
    };
    expect(delays.length, greaterThan(10));
  });
}
