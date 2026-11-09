import 'dart:io';

void main() {
  final lib = Directory('lib');
  final rawEvent = RegExp(r"AnalyticsEvent\(\s*'([a-z][a-z0-9_]{0,39})'");
  final failures = <String>[];
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    for (final match in rawEvent.allMatches(source)) {
      if (!entity.path.endsWith('core/analytics/domain/analytics_events.dart')) {
        failures.add('${entity.path}: raw event ${match.group(1)}');
      }
    }
  }
  if (failures.isNotEmpty) {
    stderr.writeln('Analytics events must be declared in Events:');
    for (final failure in failures) {
      stderr.writeln('  $failure');
    }
    exitCode = 1;
  } else {
    stdout.writeln('Analytics event catalogue: clean');
  }
}
