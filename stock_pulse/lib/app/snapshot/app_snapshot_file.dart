import 'dart:io';

import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';
import 'package:stock_pulse/core/storage/data/atomic_json_file.dart';
import 'package:stock_pulse/core/storage/data/file_snapshot_store.dart';

/// `snapshot.json` in [dir], warning over [kSnapshotBudgetBytes].
AtomicJsonFile openAppSnapshotFile(
  Future<Directory>? dir,
  CrashReporter reporter,
) => FileSnapshotStore.openFile(
  dir,
  reporter,
  budgetBytes: kSnapshotBudgetBytes,
);

/// The startup read of the [AppSnapshot]; null when absent or discarded.
Future<AppSnapshot?> readAppSnapshot(
  AtomicJsonFile file,
  CrashReporter reporter,
  Clock clock,
) => FileSnapshotStore.readInitial(
  file,
  reporter,
  clock,
  schemaVersion: kSnapshotSchema,
  maxAge: kSnapshotMaxAge,
  decode: AppSnapshot.fromJson,
);
