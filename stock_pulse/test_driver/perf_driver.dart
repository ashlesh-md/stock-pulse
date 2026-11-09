import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final metrics = data?['watchlist'];
    if (metrics == null) {
      throw StateError('watchlist performance report is missing');
    }
    final output = Directory('build/perf')..createSync(recursive: true);
    await File('${output.path}/timeline_summary.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(metrics),
    );
  },
);
