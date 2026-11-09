import 'dart:io';

final class SourceFinding {
  const SourceFinding(this.file, this.line, this.match);
  final String file;
  final int line;
  final String match;

  @override
  String toString() => '$file:$line: $match';
}

List<File> dartSources(
  Directory root, {
  bool Function(String path)? include,
}) => [
  for (final entity in root.listSync(recursive: true).whereType<File>())
    if (entity.path.endsWith('.dart') && (include?.call(entity.path) ?? true))
      entity,
];

List<SourceFinding> scanLines(
  Iterable<File> files,
  RegExp rule, {
  bool Function(String file, String line, RegExpMatch match)? allow,
}) {
  final findings = <SourceFinding>[];
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final match in rule.allMatches(lines[i])) {
        if (!(allow?.call(file.path, lines[i], match) ?? false)) {
          findings.add(
            SourceFinding(file.path, i + 1, match.group(0) ?? 'match'),
          );
        }
      }
    }
  }
  return findings;
}

void printFindings(
  String name,
  List<SourceFinding> findings, {
  bool strict = false,
}) {
  for (final finding in findings) {
    stdout.writeln(finding);
  }
  stdout.writeln('$name: ${findings.length} finding(s)');
  if (strict && findings.isNotEmpty) exitCode = 1;
}

bool strictMode(List<String> args) => args.contains('--strict');
