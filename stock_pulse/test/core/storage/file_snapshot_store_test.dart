import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot_file.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/storage/data/atomic_json_file.dart';
import 'package:stock_pulse/core/storage/data/file_local_prefs.dart';
import 'package:stock_pulse/core/storage/data/file_snapshot_store.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';

import '../../helpers/fake_crash_reporter.dart';
import 'storage_fixtures.dart';

void main() {
  late Directory dir;
  late FakeCrashReporter reporter;
  final clock = FakeClock(t0.add(const Duration(hours: 1)));

  setUp(() {
    dir = Directory.systemTemp.createTempSync('snapshot_store_');
    reporter = FakeCrashReporter();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File snapshotFile() => File('${dir.path}/${FileSnapshotStore.fileName}');
  AtomicJsonFile atomic() => openAppSnapshotFile(Future.value(dir), reporter);
  Future<AppSnapshot?> read() => readAppSnapshot(atomic(), reporter, clock);

  test('saveNow then readInitial returns the snapshot', () async {
    final store = FileSnapshotStore(atomic());
    store.markStructuralDirty();
    expect(store.isDirty, isTrue);
    await store.saveNow(snapshotWith());

    expect(store.isDirty, isFalse);
    expect(await read(), snapshotWith());
    expect(reporter.logs, isEmpty);
  });

  test('missing file: null and no log', () async {
    expect(await read(), isNull);
    expect(reporter.logs, isEmpty);
  });

  for (final (name, content, reason) in [
    (
      'schemaVersion 0',
      jsonEncode(snapshotWith().toJson()..['schemaVersion'] = 0),
      'missing_schema',
    ),
    (
      'savedAt 8 days ago',
      jsonEncode(
        snapshotWith(savedAt: clock.now().subtract(const Duration(days: 8)))
            .toJson(),
      ),
      'old',
    ),
    (
      'truncated JSON',
      jsonEncode(snapshotWith().toJson()).substring(0, 40),
      'corrupt',
    ),
  ]) {
    test('$name: null, file deleted, one cache_discarded ($reason)', () async {
      snapshotFile().writeAsStringSync(content);

      expect(await read(), isNull);
      expect(snapshotFile().existsSync(), isFalse);
      final logs = reporter.logsNamed('cache_discarded');
      expect(logs, hasLength(1));
      expect(logs.single.data['reason'], reason);
      expect(logs.single.data['bytes'], utf8.encode(content).length);
      expect(reporter.errors, isEmpty);
    });
  }

  test('a failing directory future reads null without throwing', () async {
    final broken = AtomicJsonFile(
      Future.error(const FileSystemException('no dir')),
      FileSnapshotStore.fileName,
    );
    expect(await readAppSnapshot(broken, reporter, clock), isNull);
    expect(reporter.errors, hasLength(1));
    expect(reporter.errors.single.fatal, isFalse);
  });

  test(
    'over 64 KB is still written, with one cache_oversize per run',
    () async {
      final store = FileSnapshotStore(atomic());
      final big = snapshotWith(quotes: 800);
      await store.saveNow(big);
      await store.saveNow(big);

      expect(snapshotFile().lengthSync(), greaterThan(kSnapshotBudgetBytes));
      expect(reporter.logsNamed('cache_oversize'), hasLength(1));
    },
  );

  test(
    'snapshot clear leaves prefs intact; prefs clear removes them',
    () async {
      final store = FileSnapshotStore(atomic());
      final prefs = await FileLocalPrefs(
        AtomicJsonFile(Future.value(dir), FileLocalPrefs.fileName),
        reporter,
      ).load();
      await prefs.update((p) => p.copyWith(riskNoticeAcked: true));
      await store.saveNow(snapshotWith());
      store.markStructuralDirty();

      await store.clear();
      expect(snapshotFile().existsSync(), isFalse);
      expect(store.isDirty, isFalse);
      final reloaded = await FileLocalPrefs(
        AtomicJsonFile(Future.value(dir), FileLocalPrefs.fileName),
        reporter,
      ).load();
      expect(reloaded.data.riskNoticeAcked, isTrue);

      await reloaded.clear();
      expect(reloaded.data, LocalPrefsData.defaults);
      expect(
        File('${dir.path}/${FileLocalPrefs.fileName}').existsSync(),
        isFalse,
      );
    },
  );
}
