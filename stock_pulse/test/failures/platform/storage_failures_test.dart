import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/core/storage/application/snapshot_scheduler.dart';
import 'package:stock_pulse/core/storage/data/atomic_json_file.dart';
import 'package:stock_pulse/core/storage/data/file_local_prefs.dart';
import 'package:stock_pulse/core/storage/data/file_snapshot_store.dart';

import '../../helpers/fake_crash_reporter.dart';

void main() {
  late Directory dir;
  late FakeCrashReporter reporter;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('storage_failures_');
    reporter = FakeCrashReporter();
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  AppSnapshot snapshot() => AppSnapshot(
    savedAt: DateTime.utc(2026, 11, 10),
    watchlistIds: const ['TCS'],
    quotes: const [],
    positions: const [],
    holdings: const [],
  );

  group('F11 prefs write fails', () {
    Future<FileLocalPrefs> brokenPrefs() async {
      final prefs = FileLocalPrefs(
        AtomicJsonFile(Future.value(dir), FileLocalPrefs.fileName),
        reporter,
      );
      await prefs.load();
      dir.deleteSync(recursive: true);
      return prefs;
    }

    test('the change is kept in memory and the app keeps running', () async {
      final prefs = await brokenPrefs();

      await prefs.update((d) => d.copyWith(hapticsEnabled: false));

      expect(prefs.data.hapticsEnabled, isFalse);
    });

    test('logs once however many writes fail', () async {
      final prefs = await brokenPrefs();

      for (var i = 0; i < 3; i++) {
        await prefs.update((d) => d.copyWith(riskNoticeAcked: i.isEven));
      }

      expect(reporter.logsNamed('prefs_write_failed'), hasLength(1));
    });

    test('a seen alert id is remembered for the run, so its banner never '
        'shows twice', () async {
      final prefs = await brokenPrefs();

      await prefs.update(
        (d) => d.copyWith(seenAlertIds: {...d.seenAlertIds, 'A1'}),
      );

      expect(prefs.data.seenAlertIds, contains('A1'));
    });

    test('the next save after the disk recovers is written', () async {
      final prefs = await brokenPrefs();
      await prefs.update((d) => d.copyWith(hapticsEnabled: false));

      dir.createSync();
      await prefs.update((d) => d.copyWith(riskNoticeAcked: true));

      final reloaded = await FileLocalPrefs(
        AtomicJsonFile(Future.value(dir), FileLocalPrefs.fileName),
        reporter,
      ).load();
      expect(reloaded.data.hapticsEnabled, isFalse);
      expect(reloaded.data.riskNoticeAcked, isTrue);
    });
  });

  group('F11 snapshot write fails', () {
    FileSnapshotStore brokenStore() {
      final store = FileSnapshotStore(
        AtomicJsonFile(Future.value(dir), FileSnapshotStore.fileName),
        reporter: reporter,
      );
      dir.deleteSync(recursive: true);
      return store;
    }

    test('logs once and stays dirty so the next save retries', () async {
      final store = brokenStore();

      await store.saveNow(snapshot());
      await store.saveNow(snapshot());

      expect(store.isDirty, isTrue);
      expect(reporter.logsNamed('cache_write_failed'), hasLength(1));
    });

    test('the scheduler save on hide never throws into the zone', () async {
      final store = brokenStore();
      final scheduler = SnapshotScheduler(
        store: store,
        isDirty: () => store.isDirty,
        capture: snapshot,
        hasLiveData: () => true,
        isLive: () => true,
        resyncCompleted: const Stream.empty(),
      );
      addTearDown(scheduler.dispose);

      scheduler.onHide();
      await pumpEventQueue();

      expect(reporter.logsNamed('cache_write_failed'), hasLength(1));
    });

    test('a later save after the disk recovers is written', () async {
      final store = brokenStore();
      await store.saveNow(snapshot());

      dir.createSync();
      await store.saveNow(snapshot());

      expect(store.isDirty, isFalse);
      expect(
        File('${dir.path}/${FileSnapshotStore.fileName}').existsSync(),
        isTrue,
      );
    });
  });
}
