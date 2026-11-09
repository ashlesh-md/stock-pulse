import 'dart:io';

import 'source_scan.dart';

final _choiceWidget = RegExp(
  r'\b(?:DropdownButton\w*|DropdownMenu\w*|PopupMenuButton)\b',
);

List<SourceFinding> dropdownFindings(Directory lib) =>
    scanLines(dartSources(lib), _choiceWidget);

void main(List<String> args) {
  printFindings(
    'choice dropdown widgets',
    dropdownFindings(Directory('lib')),
    strict: strictMode(args),
  );
}
