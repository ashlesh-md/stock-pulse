import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _script = File('tool/ci/deny_list.sh').absolute.path;

void main() {
  late Directory repo;

  setUp(() => repo = Directory.systemTemp.createTempSync('deny_list'));
  tearDown(() => repo.deleteSync(recursive: true));

  void write(String path, String text) {
    File('${repo.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }

  Future<ProcessResult> run([List<String> extra = const []]) =>
      Process.run('bash', [_script, repo.path, ...extra]);

  test('passes a clean tree', () async {
    write(
      'stock_pulse/lib/a.dart',
      "part 'routes.dart';\nfinal a = context.strings.title;\n",
    );

    final result = await run();

    expect(result.exitCode, 0, reason: '${result.stdout}');
    expect(result.stdout, contains('0 deny-list hits'));
  });

  test('flags each banned pattern with its rule and location', () async {
    write('stock_pulse/lib/features/x/w.dart', '''
part 'w.g.dart';
final c = Colors.red;
final i = Icons.add;
final p = 'assets/logo.png';
final t = Text('Buy');
void f() => ScaffoldMessenger.of(ctx).showSnackBar(s);
void g() => context.go('/stock/TCS');
void h() => print('x');
''');
    write('stock_pulse/lib/barrel.dart', "export 'a.dart';\n");
    write(
      'market_server/pubspec.yaml',
      'dev_dependencies:\n  build_runner: any\n',
    );

    final result = await run();
    final out = '${result.stdout}';

    expect(result.exitCode, 1);
    for (final rule in [
      'codegen',
      'export-barrel',
      'colors',
      'icons',
      'asset-path',
      'text-literal',
      'snackbar',
      'route-path',
      'print',
    ]) {
      expect(out, contains('$rule: '), reason: rule);
    }
    expect(out, contains('stock_pulse/lib/features/x/w.dart:2:'));
  });

  test('allows each pattern in the one file that owns it', () async {
    write(
      'stock_pulse/lib/core/theme/sp_colors.dart',
      'final c = Colors.red;\n',
    );
    write(
      'stock_pulse/lib/core/assets/app_icons.dart',
      'final i = Icons.add;\n',
    );
    write(
      'stock_pulse/lib/core/assets/app_images.dart',
      "final p = 'assets/a.png';\n",
    );
    write(
      'stock_pulse/lib/core/feedback/presentation/feedback_host.dart',
      'void f() => m.showSnackBar(s);\n',
    );
    write(
      'stock_pulse/lib/features/market/presentation/market_routes.dart',
      "final r = GoRoute(path: '/stock/:id');\n",
    );
    write(
      'stock_pulse/lib/core/observability/log.dart',
      'void f() => debugPrint(m);\n',
    );

    final result = await run();

    expect(result.exitCode, 0, reason: '${result.stdout}');
  });

  test('report-only prints hits but exits 0', () async {
    write('stock_pulse/lib/a.dart', 'final c = Colors.red;\n');

    final result = await run(['--report-only']);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('1 deny-list hits'));
  });
}
