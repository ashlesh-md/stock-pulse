import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:path_provider/path_provider.dart';
import 'package:stock_pulse/app/app.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot_file.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/observability/data/debug_crash_reporter.dart';
import 'package:stock_pulse/core/observability/data/paint_probe.dart';
import 'package:stock_pulse/core/observability/data/perf_marks.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';
import 'package:stock_pulse/core/storage/data/atomic_json_file.dart';
import 'package:stock_pulse/core/storage/data/file_local_prefs.dart';
import 'package:stock_pulse/core/storage/data/file_snapshot_store.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';

/// The only code that runs before `runApp`. Synchronous: it
/// starts the disk reads and never awaits them, so the first frame paints
/// the shell and the watchlist skeleton while the cache is still loading.
/// Tests pass [overrides] to swap the network for fakes.
void bootstrap({List<Override> overrides = const []}) {
  WidgetsFlutterBinding.ensureInitialized();
  PerfMarks.mark('main_start');
  final reporter = DebugCrashReporter();
  installCrashHooks(reporter);
  PaintProbe.install();
  if (!kReleaseMode) {
    Timer(const Duration(seconds: 10), StartupMarks.printPerfLineOnce);
  }
  // Not awaited. Web has no file system: no cache, prefs in memory only.
  final dir = kIsWeb ? null : getApplicationSupportDirectory();
  final snapshotFile = openAppSnapshotFile(dir, reporter);
  final snapshot = readAppSnapshot(snapshotFile, reporter, const SystemClock());
  // No IO until the first localPrefsProvider read.
  final prefs = FileLocalPrefs(
    AtomicJsonFile(dir, FileLocalPrefs.fileName),
    reporter,
  );
  runApp(
    appScope(
      reporter: reporter,
      snapshot: snapshot,
      overrides: [
        snapshotStoreProvider.overrideWithValue(
          FileSnapshotStore(snapshotFile),
        ),
        localPrefsProvider.overrideWith((ref) => prefs.load()),
        ...overrides,
      ],
    ),
  );
}

/// The root widget with the startup overrides. Tests call it with fakes and
/// a pending [snapshot] future.
Widget appScope({
  required CrashReporter reporter,
  required Future<AppSnapshot?> snapshot,
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: [
    crashReporterProvider.overrideWithValue(reporter),
    snapshotProvider.overrideWith((ref) => snapshot),
    ...overrides,
  ],
  child: const StockPulseApp(),
);
