import 'dart:io';

import 'source_scan.dart';

final _formatConstructor = RegExp(r'\b(?:NumberFormat|DateFormat)\s*\(');

List<SourceFinding> formatterFindings(Directory lib) => scanLines(
  dartSources(lib, include: (path) => !path.contains('/core/format/')),
  _formatConstructor,
);

void main(List<String> args) {
  printFindings(
    'formatter constructors outside core/format',
    formatterFindings(Directory('lib')),
    strict: strictMode(args),
  );
}
