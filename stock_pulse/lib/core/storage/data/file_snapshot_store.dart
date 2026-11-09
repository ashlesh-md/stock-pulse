import 'dart:convert';
import 'dart:io';

import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/observability/data/perf_marks.dart';
import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';
import 'package:stock_pulse/core/storage/data/atomic_json_file.dart';
import 'package:stock_pulse/core/storage/domain/snapshot.dart';
import 'package:stock_pulse/core/storage/domain/snapshot_store.dart';

/// The app's [SnapshotStore], created in `bootstrap()` on the same
/// [AtomicJsonFile] that [readInitial] used, so there is one writer.
class FileSnapshotStore implements SnapshotStore {
  FileSnapshotStore(this._file);

  static const fileName = 'snapshot.json';

  final AtomicJsonFile _file;
  bool _dirty = false;

  /// Read by `SnapshotScheduler` for its 30 s save.
  bool get isDirty => _dirty;

  /// The file for [readInitial] and this store. Logs `cache_oversize` once
  /// per run when a write is over [budgetBytes]; it is still written.
  static AtomicJsonFile openFile(
    Future<Directory>? dir,
    CrashReporter reporter, {
    required int budgetBytes,
  }) {
    var warned = false;
    return AtomicJsonFile(
      dir,
      fileName,
      onWritten: (bytes) {
        if (bytes <= budgetBytes || warned) return;
        warned = true;
        reporter.log('cache_oversize', {'bytes': bytes});
      },
    );
  }

  /// The startup read, started before `runApp` and never awaited there.
  /// Never throws: no file, a `schemaVersion` other than [schemaVersion],
  /// older than [maxAge] or bad JSON all give null; each discard deletes the
  /// file and logs one `cache_discarded {reason, bytes}`. A missing file is
  /// not logged. [decode] throws [FormatException] on a bad field.
  static Future<T?> readInitial<T extends Snapshot>(
    AtomicJsonFile file,
    CrashReporter reporter,
    Clock clock, {
    required int schemaVersion,
    required Duration maxAge,
    required T Function(Map<String, Object?> json) decode,
  }) async {
    try {
      final String? text;
      try {
        text = await file.readString();
      } on Object catch (e, s) {
        reporter.recordError(e, s, reason: 'cache_read');
        return null;
      }
      if (text == null) return null;

      Future<T?> discard(String reason) async {
        reporter.log('cache_discarded', {
          'reason': reason,
          'bytes': utf8.encode(text!).length,
        });
        await file.delete();
        return null;
      }

      final Object? decoded;
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        return await discard('corrupt');
      }
      if (decoded is! Map<String, Object?>) return await discard('corrupt');
      if (decoded['schemaVersion'] != schemaVersion) {
        return await discard('missing_schema');
      }
      final T snapshot;
      try {
        snapshot = decode(decoded);
      } on FormatException {
        return await discard('corrupt');
      }
      if (clock.now().difference(snapshot.savedAt) > maxAge) {
        return await discard('old');
      }
      return snapshot;
    } on Object catch (e, s) {
      reporter.recordError(e, s, reason: 'cache_read');
      return null;
    } finally {
      PerfMarks.mark('cache_read_done');
    }
  }

  @override
  void markStructuralDirty() => _dirty = true;

  @override
  Future<void> saveNow(Snapshot s) {
    _dirty = false;
    return _file.write(s.toJson());
  }

  @override
  Future<void> clear() {
    _dirty = false;
    return _file.delete();
  }
}
