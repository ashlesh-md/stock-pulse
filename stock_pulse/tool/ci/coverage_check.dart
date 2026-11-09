import 'dart:io';

/// Files outside the gate (the entry point and generated locale tables),
/// relative to the package root.
const excludedPrefixes = ['lib/main.dart', 'lib/core/l10n/locales/'];

const importTestPath = 'test/coverage/all_imports_test.dart';

final class CoverageReport {
  CoverageReport({
    required this.covered,
    required this.total,
    required this.uncovered,
    required this.unloadedFiles,
    required this.markerErrors,
  });

  final int covered;
  final int total;

  /// `path:line` of every executable line no test ran.
  final List<String> uncovered;

  /// `lib/` files missing from lcov. With an up-to-date import test this
  /// means the file has no executable lines (enums, constants); otherwise
  /// that no test loaded it.
  final List<String> unloadedFiles;

  /// Ignore markers other than a block guarding `kPerfProbe`.
  final List<String> markerErrors;

  double get percent => total == 0 ? 100 : covered * 100 / total;
}

/// Line hits per file from lcov `SF:` / `DA:` records, keyed by the path
/// from `lib/` on, so absolute and relative `SF:` paths compare equal.
Map<String, Map<int, int>> parseLcov(String lcov) {
  final hits = <String, Map<int, int>>{};
  Map<int, int>? current;
  for (final line in lcov.split('\n')) {
    if (line.startsWith('SF:')) {
      current = hits.putIfAbsent(libRelative(line.substring(3)), () => {});
    } else if (line.startsWith('DA:') && current != null) {
      final [lineNo, count, ...] = line.substring(3).split(',');
      current.update(
        int.parse(lineNo),
        (old) => old + int.parse(count),
        ifAbsent: () => int.parse(count),
      );
    } else if (line == 'end_of_record') {
      current = null;
    }
  }
  return hits;
}

String libRelative(String path) {
  final normal = path.replaceAll(r'\', '/');
  if (normal.startsWith('lib/')) return normal;
  final at = normal.lastIndexOf('/lib/');
  return at < 0 ? normal : normal.substring(at + 1);
}

bool isExcluded(String libPath) =>
    excludedPrefixes.any((prefix) => libPath.startsWith(prefix));

/// Lines inside `coverage:ignore-start` … `-end` blocks that guard
/// `kPerfProbe`, plus an error for every other ignore marker.
({Set<int> ignored, List<String> errors}) scanIgnoreMarkers(
  String path,
  List<String> lines,
) {
  final ignored = <int>{};
  final errors = <String>[];
  int? blockStart;
  for (var i = 0; i < lines.length; i++) {
    final text = lines[i];
    final lineNo = i + 1;
    if (text.contains('coverage:ignore-start')) {
      final guarded = i + 1 < lines.length ? lines[i + 1] : '';
      if (guarded.contains('kPerfProbe')) {
        blockStart = lineNo;
      } else {
        errors.add('$path:$lineNo ignore block does not guard kPerfProbe');
      }
    } else if (text.contains('coverage:ignore-end')) {
      if (blockStart != null) {
        ignored.addAll([for (var n = blockStart; n <= lineNo; n++) n]);
      }
      blockStart = null;
    } else if (text.contains('coverage:ignore-line') ||
        text.contains('coverage:ignore-file')) {
      errors.add('$path:$lineNo ignore marker not allowed');
    }
  }
  return (ignored: ignored, errors: errors);
}

/// [sources] maps every `lib/` path of the package to its lines.
CoverageReport checkCoverage(
  Map<String, Map<int, int>> hits,
  Map<String, List<String>> sources,
) {
  var covered = 0;
  var total = 0;
  final uncovered = <String>[];
  final unloaded = <String>[];
  final markerErrors = <String>[];
  final paths = sources.keys.where((p) => !isExcluded(p)).toList()..sort();
  for (final path in paths) {
    final markers = scanIgnoreMarkers(path, sources[path]!);
    markerErrors.addAll(markers.errors);
    final fileHits = hits[path];
    if (fileHits == null) {
      unloaded.add(path);
      continue;
    }
    final lineNos = fileHits.keys.toList()..sort();
    for (final lineNo in lineNos) {
      if (markers.ignored.contains(lineNo)) continue;
      total++;
      if (fileHits[lineNo]! > 0) {
        covered++;
      } else {
        uncovered.add('$path:$lineNo');
      }
    }
  }
  return CoverageReport(
    covered: covered,
    total: total,
    uncovered: uncovered,
    unloadedFiles: unloaded,
    markerErrors: markerErrors,
  );
}

/// A test that imports every `lib/` file, so files no other test loads
/// still show up in lcov (with zero hits).
String importTestSource(String packageName, Iterable<String> libPaths) {
  final imports = [
    for (final path in libPaths.toList()..sort())
      "import 'package:$packageName/${path.substring(4)}';",
  ];
  return [
    '// Written by tool/ci/coverage_check.dart --write-import-test.',
    '// ignore_for_file: unused_import, directives_ordering',
    ...imports,
    '',
    'void main() {}',
    '',
  ].join('\n');
}

Map<String, List<String>> readLibSources(Directory lib) => {
  for (final file in lib.listSync(recursive: true).whereType<File>())
    if (file.path.endsWith('.dart'))
      libRelative(file.path): file.readAsLinesSync(),
};

String readPackageName(File pubspec) {
  final line = pubspec.readAsLinesSync().firstWhere(
    (l) => l.startsWith('name:'),
  );
  return line.substring('name:'.length).trim();
}

/// Why the import test cannot vouch for absent files, or null when it
/// imports exactly the current `lib/` files.
String? importTestProblem(String? actual, String expected) => switch (actual) {
  null => 'missing $importTestPath',
  _ when actual != expected => 'stale $importTestPath',
  _ => null,
};

void _printReport(CoverageReport report, double min, {String? importProblem}) {
  for (final error in report.markerErrors) {
    stdout.writeln('marker: $error');
  }
  if (importProblem != null) {
    stdout.writeln('import test: $importProblem; run with --write-import-test');
  }
  for (final path in report.unloadedFiles) {
    stdout.writeln(
      importProblem == null
          ? 'no executable lines: $path'
          : 'not loaded by any test: $path',
    );
  }
  for (final line in report.uncovered) {
    stdout.writeln('uncovered: $line');
  }
  stdout.writeln(
    'coverage ${report.percent.toStringAsFixed(2)} % '
    '(${report.covered}/${report.total} lines, '
    '${report.unloadedFiles.length} files absent from lcov, min $min %)',
  );
}

/// Usage, from a package root:
///   `dart run <path>/coverage_check.dart --write-import-test`
///   `dart run <path>/coverage_check.dart coverage/lcov.info --lib lib --min 100`
///
/// Fails below `--min`, on a disallowed ignore marker, and when the import
/// test is missing or stale, because then an absent file may hide
/// executable lines no test loaded.
void main(List<String> args) {
  final libIndex = args.indexOf('--lib');
  final lib = libIndex < 0 ? 'lib' : args[libIndex + 1];
  final sources = readLibSources(Directory(lib));
  final expectedImports = importTestSource(
    readPackageName(File('pubspec.yaml')),
    sources.entries
        .where(
          (entry) => !entry.value.any((line) => line.startsWith('part of ')),
        )
        .map((entry) => entry.key),
  );
  final importTest = File(importTestPath);
  if (args.contains('--write-import-test')) {
    importTest
      ..createSync(recursive: true)
      ..writeAsStringSync(expectedImports);
    return;
  }
  final minIndex = args.indexOf('--min');
  final min = minIndex < 0 ? 100.0 : double.parse(args[minIndex + 1]);
  final report = checkCoverage(
    parseLcov(File(args.first).readAsStringSync()),
    sources,
  );
  final importProblem = importTestProblem(
    importTest.existsSync() ? importTest.readAsStringSync() : null,
    expectedImports,
  );
  _printReport(report, min, importProblem: importProblem);
  final unloaded = importProblem != null && report.unloadedFiles.isNotEmpty;
  final blocking = min > 0 && (unloaded || report.markerErrors.isNotEmpty);
  if (report.percent < min || blocking) exitCode = 1;
}
