import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';

import 'storage_fixtures.dart';

void main() {
  // Coarse guard only; real numbers come from device runs.
  test('median of 20 decodes of a 64 KB snapshot is <= 4 ms', () {
    var quotes = 50;
    var text = '';
    while (true) {
      text = jsonEncode(
        snapshotWith(quotes: quotes, positions: 20, holdings: 20).toJson(),
      );
      if (utf8.encode(text).length >= kSnapshotBudgetBytes) break;
      quotes += 10;
    }

    // Warm up the JIT so the first runs do not count.
    for (var i = 0; i < 5; i++) {
      AppSnapshot.fromJson(jsonDecode(text) as Map<String, Object?>);
    }
    final micros = <int>[];
    for (var i = 0; i < 20; i++) {
      final sw = Stopwatch()..start();
      AppSnapshot.fromJson(jsonDecode(text) as Map<String, Object?>);
      micros.add(sw.elapsedMicroseconds);
    }
    micros.sort();
    final median = micros[micros.length ~/ 2];
    expect(median, lessThanOrEqualTo(4000), reason: 'median $median us');
  });
}
