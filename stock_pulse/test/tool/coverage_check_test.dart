import 'package:flutter_test/flutter_test.dart';

import '../../tool/ci/coverage_check.dart';

void main() {
  group('parseLcov', () {
    test('reads hits per line and keys files from lib/ on', () {
      const lcov = '''
SF:/repo/stock_pulse/lib/a.dart
DA:1,3
DA:2,0
end_of_record
SF:lib/b.dart
DA:5,1
end_of_record
''';

      expect(parseLcov(lcov), {
        'lib/a.dart': {1: 3, 2: 0},
        'lib/b.dart': {5: 1},
      });
    });

    test('adds hits when a file appears in two records', () {
      const lcov =
          'SF:lib/a.dart\nDA:1,0\nend_of_record\n'
          'SF:lib/a.dart\nDA:1,2\nend_of_record\n';

      expect(parseLcov(lcov), {
        'lib/a.dart': {1: 2},
      });
    });
  });

  group('checkCoverage', () {
    test('lists uncovered lines and the percentage', () {
      final report = checkCoverage(
        {
          'lib/a.dart': {1: 1, 2: 0, 3: 1, 4: 1},
        },
        {'lib/a.dart': List.filled(4, 'x')},
      );

      expect(report.percent, 75);
      expect(report.uncovered, ['lib/a.dart:2']);
    });

    test('reports a lib file that no test loaded', () {
      final report = checkCoverage({}, {
        'lib/lonely.dart': ['x'],
      });

      expect(report.unloadedFiles, ['lib/lonely.dart']);
    });

    test('drops main.dart and locale tables (E1, E2)', () {
      final report = checkCoverage(
        {
          'lib/main.dart': {1: 0},
          'lib/core/l10n/locales/en/strings.dart': {1: 0},
        },
        {
          'lib/main.dart': ['x'],
          'lib/core/l10n/locales/en/strings.dart': ['x'],
        },
      );

      expect(report.total, 0);
      expect(report.unloadedFiles, isEmpty);
    });

    test('skips lines inside an ignore block that guards kPerfProbe (E3)', () {
      final source = [
        'void f() {',
        '  // coverage:ignore-start',
        '  if (kPerfProbe) probe();',
        '  // coverage:ignore-end',
        '}',
      ];

      final report = checkCoverage(
        {
          'lib/p.dart': {1: 1, 3: 0},
        },
        {'lib/p.dart': source},
      );

      expect(report.uncovered, isEmpty);
      expect(report.markerErrors, isEmpty);
    });

    test('rejects ignore markers ADR-0020 does not allow', () {
      final source = [
        '// coverage:ignore-file',
        'int a = 1; // coverage:ignore-line',
        '// coverage:ignore-start',
        'int b = 2;',
        '// coverage:ignore-end',
      ];

      final report = checkCoverage(
        {
          'lib/p.dart': {2: 0, 4: 0},
        },
        {'lib/p.dart': source},
      );

      expect(report.markerErrors, hasLength(3));
      expect(report.uncovered, ['lib/p.dart:2', 'lib/p.dart:4']);
    });
  });

  test('import test imports every lib file by package URI', () {
    final source = importTestSource('demo', ['lib/b.dart', 'lib/a/x.dart']);

    expect(source, contains("import 'package:demo/a/x.dart';"));
    expect(source, contains("import 'package:demo/b.dart';"));
    expect(source, contains('void main() {}'));
  });

  test('a missing or stale import test cannot vouch for absent files', () {
    final expected = importTestSource('demo', ['lib/a.dart']);

    expect(importTestProblem(null, expected), contains('missing'));
    expect(importTestProblem('void main() {}', expected), contains('stale'));
    expect(importTestProblem(expected, expected), isNull);
  });

  test('libRelative keeps relative paths and cuts absolute ones at lib/', () {
    expect(libRelative('lib/a.dart'), 'lib/a.dart');
    expect(libRelative('/x/lib/y/lib/a.dart'), 'lib/a.dart');
    expect(libRelative(r'C:\p\lib\a.dart'), 'lib/a.dart');
  });
}
