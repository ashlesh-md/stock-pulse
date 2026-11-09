import 'dart:io';

import 'source_scan.dart';

final _assetLiteral = RegExp(r"""(['"])(assets/[^'"]+)\1""");

List<SourceFinding> assetRegistryFindings(Directory lib) => scanLines(
  dartSources(
    lib,
    include: (path) => !path.endsWith('/core/assets/app_images.dart'),
  ),
  _assetLiteral,
);

void main(List<String> args) {
  printFindings(
    'unregistered asset paths',
    assetRegistryFindings(Directory('lib')),
    strict: strictMode(args),
  );
}
