import 'dart:io';

const lineLimit = 300;

const scannedDirs = [
  'stock_pulse/lib',
  'stock_pulse/test',
  'stock_pulse/integration_test',
  'stock_pulse/tool',
  'market_server/lib',
  'market_server/bin',
  'market_server/test',
  'packages/option_math/lib',
  'packages/option_math/test',
];

typedef LongFile = ({String path, int lines});

/// Dart files under [scannedDirs] of [repoRoot] with more than [limit] lines,
/// sorted by path. Paths are relative to [repoRoot] with `/` separators.
List<LongFile> findLongFiles(
  Directory repoRoot, {
  int limit = lineLimit,
  Set<String> allowed = const {},
}) {
  final offenders = <LongFile>[];
  for (final dir in scannedDirs) {
    final root = Directory('${repoRoot.path}/$dir');
    if (!root.existsSync()) continue;
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final path = file.path.substring(repoRoot.path.length + 1);
      if (allowed.contains(path)) continue;
      final lines = countLines(file.readAsStringSync());
      if (lines > limit) offenders.add((path: path, lines: lines));
    }
  }
  return offenders..sort((a, b) => a.path.compareTo(b.path));
}

/// Physical lines as `wc -l` counts them, plus a last line without `\n`.
int countLines(String text) {
  if (text.isEmpty) return 0;
  final newlines = '\n'.allMatches(text).length;
  return text.endsWith('\n') ? newlines : newlines + 1;
}

/// Entries of the allow-list: one repo-relative path per line, then
/// ` # reason`. Blank lines and lines starting with `#` are skipped.
Set<String> readAllowList(File file) {
  if (!file.existsSync()) return const {};
  return {
    for (final line in file.readAsLinesSync())
      if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
        line.split('#').first.trim(),
  };
}

/// Run from `stock_pulse/`. `--report-only` prints offenders but exits 0.
void main(List<String> args) {
  final repoRoot = Directory.current.parent;
  final allowed = readAllowList(File('tool/ci/file_length_allowlist.txt'));
  final offenders = findLongFiles(repoRoot, allowed: allowed);
  for (final f in offenders) {
    stdout.writeln('${f.path}: ${f.lines} lines (limit $lineLimit)');
  }
  stdout.writeln('${offenders.length} files over $lineLimit lines');
  if (offenders.isNotEmpty && !args.contains('--report-only')) exitCode = 1;
}
