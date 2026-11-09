import 'dart:io';

import 'source_scan.dart';

final _textLiteral = RegExp(
  r"""(?:Text|SelectableText)\s*\(\s*(?:text:\s*)?(['"])([^'"]*)\1|TextSpan\s*\(\s*text:\s*(['"])([^'"]*)\3""",
);
final _symbolsOrNumbers = RegExp(r'^[\d\s.,:%+\-/₹$()#]*$');
final _socketFrameText = RegExp(
  r'\b(?:frame|sequence|payload)\b',
  caseSensitive: false,
);

List<SourceFinding> stringLiteralFindings(Directory lib) => scanLines(
  dartSources(
    lib,
    include: (path) =>
        path.contains('/presentation/') || path.contains('/core/widgets/'),
  ),
  _textLiteral,
  allow: (file, line, match) {
    final value = match.group(2) ?? match.group(4) ?? '';
    return (file.endsWith('/socket_lab_screen.dart') &&
            _socketFrameText.hasMatch(value)) ||
        value.isEmpty ||
        _symbolsOrNumbers.hasMatch(value);
  },
);

void main(List<String> args) {
  printFindings(
    'user-facing string literals',
    stringLiteralFindings(Directory('lib')),
    strict: strictMode(args),
  );
}
