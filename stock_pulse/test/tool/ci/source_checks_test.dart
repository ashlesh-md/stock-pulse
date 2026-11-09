import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/ci/asset_registry_check.dart';
import '../../../tool/ci/formatter_check.dart';
import '../../../tool/ci/no_dropdown_check.dart';
import '../../../tool/ci/string_literal_check.dart';

void main() {
  late Directory root;
  late Directory lib;

  setUp(() {
    root = Directory.systemTemp.createTempSync('source-check-');
    lib = Directory('${root.path}/lib')..createSync();
  });

  tearDown(() => root.deleteSync(recursive: true));

  File source(String path, String content) {
    final file = File('${lib.path}/$path')..createSync(recursive: true);
    return file..writeAsStringSync(content);
  }

  test(
    'string check reports user text and allows symbols/numbers/socket frames',
    () {
      source(
        'features/demo/presentation/demo.dart',
        "Text('Buy');\nText('₹1,234');\nText('42');",
      );
      source(
        'features/more/presentation/screens/socket_lab_screen.dart',
        "Text('frame: \$sequence');\nText('Socket Lab');",
      );

      final findings = stringLiteralFindings(lib);
      expect(findings, hasLength(2));
      expect(
        findings.map((finding) => finding.toString()),
        contains(contains('demo.dart:1:')),
      );
      expect(
        findings.map((finding) => finding.toString()),
        contains(contains('socket_lab_screen.dart:2:')),
      );
    },
  );

  test('asset check reports literal paths outside the image registry', () {
    source('features/demo/image.dart', "Image.asset('assets/demo.png');");
    source(
      'core/assets/app_images.dart',
      "const image = 'assets/registered.png';",
    );

    final findings = assetRegistryFindings(lib);
    expect(findings, hasLength(1));
    expect(findings.single.toString(), contains('image.dart:1:'));
  });

  test('formatter check reports constructors outside core/format', () {
    source('features/demo/price.dart', "final f = NumberFormat('0.00');");
    source('core/format/formatters.dart', "final f = DateFormat('yyyy');");

    final findings = formatterFindings(lib);
    expect(findings, hasLength(1));
    expect(findings.single.toString(), contains('price.dart:1:'));
  });

  test('dropdown check reports each disallowed choice control', () {
    source(
      'features/demo/choice.dart',
      'DropdownButton<String>();\nPopupMenuButton<int>();',
    );

    final findings = dropdownFindings(lib);
    expect(findings, hasLength(2));
    expect(findings.first.toString(), contains('choice.dart:1:'));
    expect(findings.last.toString(), contains('choice.dart:2:'));
  });
}
