import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot_file.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';
import 'package:stock_pulse/core/storage/data/atomic_json_file.dart';
import 'package:stock_pulse/core/storage/data/file_snapshot_store.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';

import '../../helpers/fake_crash_reporter.dart';
import 'storage_fixtures.dart';

class _ThrowingLogReporter extends FakeCrashReporter {
  @override
  void log(String event, [Map<String, Object?> data = const {}]) =>
      throw StateError('sink down');
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('storage_edges_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File snapshotFile() => File('${dir.path}/${FileSnapshotStore.fileName}');
  Future<AppSnapshot?> read(CrashReporter reporter) => readAppSnapshot(
    openAppSnapshotFile(Future.value(dir), reporter),
    reporter,
    const SystemClock(),
  );

  test('the storage providers must be overridden', () {
    final c = ProviderContainer.test();
    expect(() => c.read(snapshotStoreProvider), throwsA(anything));
    expect(c.read(snapshotProvider).hasError, isTrue);
    expect(c.read(localPrefsProvider).hasError, isTrue);
  });

  test('F6: right schema with a bad field is discarded as corrupt', () async {
    final reporter = FakeCrashReporter();
    snapshotFile().writeAsStringSync(
      jsonEncode({'schemaVersion': kSnapshotSchema, 'savedAt': 'x'}),
    );

    expect(await read(reporter), isNull);
    expect(
      reporter.logsNamed('cache_discarded').single.data['reason'],
      'corrupt',
    );
  });

  test(
    'F11: a reporter that throws while discarding still reads null',
    () async {
      final reporter = _ThrowingLogReporter();
      snapshotFile().writeAsStringSync('{bad');

      expect(await read(reporter), isNull);
      expect(reporter.errors.single.reason, 'cache_read');
    },
  );

  test('F11: a write into a missing directory fails that write only', () async {
    final file = AtomicJsonFile(Future.value(dir), 'x.json');
    dir.deleteSync(recursive: true);

    await expectLater(
      file.write({'a': 1}),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('fromJson rejects another schema; copyWith and hashCode', () {
    expect(
      () => AppSnapshot.fromJson({'schemaVersion': 99}),
      throwsFormatException,
    );
    final s = snapshotWith();
    expect(s.copyWith(), s);
    expect(s.copyWith().hashCode, s.hashCode);
    final changed = s.copyWith(
      savedAt: t0.add(const Duration(minutes: 1)),
      watchlistIds: const ['A'],
      quotes: const [],
      positions: const [],
      holdings: const [],
    );
    expect(changed.watchlistIds, ['A']);
    expect(changed == s, isFalse);
  });
}
