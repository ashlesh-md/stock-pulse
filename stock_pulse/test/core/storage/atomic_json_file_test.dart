import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/storage/data/atomic_json_file.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('atomic_json_'));
  tearDown(() => dir.deleteSync(recursive: true));

  AtomicJsonFile file() => AtomicJsonFile(Future.value(dir), 'x.json');
  File main() => File('${dir.path}/x.json');
  File tmp() => File('${dir.path}/x.json.tmp');

  test('write then read returns the map; no tmp left', () async {
    final f = file();
    await f.write({'a': 1});
    expect(await f.read(), {'a': 1});
    expect(tmp().existsSync(), isFalse);
  });

  test('missing file reads null', () async {
    expect(await file().read(), isNull);
  });

  test('a valid main file wins over a leftover .tmp', () async {
    main().writeAsStringSync(jsonEncode({'v': 'main'}));
    tmp().writeAsStringSync('{"v": "half-writ');

    expect(await file().read(), {'v': 'main'});
    expect(tmp().existsSync(), isFalse);
  });

  test(
    '3 writes while one is in flight: 2 disk writes, the 3rd wins',
    () async {
      final f = file();
      final first = f.write({'n': 1}); // in flight
      final second = f.write({'n': 2}); // pending
      final third = f.write({'n': 3}); // replaces pending
      await Future.wait([first, second, third]);

      expect(f.diskWrites, 2);
      expect(jsonDecode(main().readAsStringSync()), {'n': 3});
    },
  );

  test(
    'delete waits for the write, drops pending, removes both files',
    () async {
      final f = file();
      final a = f.write({'n': 1});
      final b = f.write({'n': 2});
      tmp().writeAsStringSync('x');
      await f.delete();
      await Future.wait([a, b]);

      expect(main().existsSync(), isFalse);
      expect(tmp().existsSync(), isFalse);
      expect(f.diskWrites, 1);
    },
  );

  test('no directory (web): read null, write and delete are no-ops', () async {
    final f = AtomicJsonFile(null, 'x.json');
    await f.write({'a': 1});
    expect(await f.read(), isNull);
    await f.delete();
    expect(f.diskWrites, 0);
  });
}
