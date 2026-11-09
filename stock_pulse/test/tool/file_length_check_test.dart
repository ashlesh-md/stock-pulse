import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci/file_length_check.dart';

void main() {
  late Directory repo;

  setUp(() => repo = Directory.systemTemp.createTempSync('file_length'));
  tearDown(() => repo.deleteSync(recursive: true));

  void write(String path, int lines) {
    File('${repo.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync('// line\n' * lines);
  }

  test('reports a Dart file over the limit with its line count', () {
    write('stock_pulse/lib/big.dart', 301);
    write('stock_pulse/lib/ok.dart', 300);

    expect(findLongFiles(repo), [
      (path: 'stock_pulse/lib/big.dart', lines: 301),
    ]);
  });

  test('scans every package and sorts offenders by path', () {
    write('packages/option_math/test/b.dart', 400);
    write('market_server/bin/a.dart', 350);

    expect(findLongFiles(repo).map((f) => f.path), [
      'market_server/bin/a.dart',
      'packages/option_math/test/b.dart',
    ]);
  });

  test('ignores non-Dart files and folders outside the scanned list', () {
    write('stock_pulse/lib/notes.md', 500);
    write('stock_pulse/build/gen.dart', 500);

    expect(findLongFiles(repo), isEmpty);
  });

  test('skips files on the allow-list', () {
    write('stock_pulse/lib/big.dart', 400);

    expect(findLongFiles(repo, allowed: {'stock_pulse/lib/big.dart'}), isEmpty);
  });

  test('counts lines like wc -l, plus a last line without a newline', () {
    expect(countLines(''), 0);
    expect(countLines('a\nb\n'), 2);
    expect(countLines('a\nb'), 2);
  });

  test('allow-list reads paths and drops comments and reasons', () {
    final file = File('${repo.path}/allow.txt')
      ..writeAsStringSync('# header\n\nlib/a.dart # split in R-3\n');

    expect(readAllowList(file), {'lib/a.dart'});
    expect(readAllowList(File('${repo.path}/missing.txt')), isEmpty);
  });
}
