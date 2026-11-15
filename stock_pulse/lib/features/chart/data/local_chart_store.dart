import 'dart:io';

import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';
import 'package:stock_pulse/core/storage/data/atomic_json_file.dart';
import 'package:stock_pulse/features/chart/domain/chart_layout.dart';
import 'package:stock_pulse/features/chart/domain/chart_prefs.dart';
import 'package:stock_pulse/features/chart/domain/chart_store.dart';

class LocalChartStore implements ChartStore {
  LocalChartStore(this.directory, this.reporter) {
    directory?.ignore();
  }
  final Future<Directory>? directory;
  final CrashReporter reporter;
  final _memory = <String, Map<String, Object?>>{};
  final _writes = <String, Future<Result<void>>>{};
  static const prefsName = 'chart.prefs.json';
  String _name(String symbol) => 'chart.${Uri.encodeComponent(symbol)}.json';

  Future<T> _read<T>(
    String name,
    T Function(Map<String, Object?>) decode,
    T fallback,
  ) async {
    try {
      final json = directory == null
          ? _memory[name]
          : await AtomicJsonFile(directory, name).read();
      return json == null ? fallback : decode(json);
    } on Object {
      reporter.log('chart_discarded', {'file': name});
      _memory.remove(name);
      try {
        await AtomicJsonFile(directory, name).delete();
      } on Object {
        reporter.log('chart_delete_failed');
      }
      return fallback;
    }
  }

  @override
  Future<ChartLayout> load(String symbol) async {
    await _writes[_name(symbol)];
    return _read(_name(symbol), ChartLayout.fromJson, ChartLayout());
  }

  @override
  Future<Result<void>> save(String symbol, ChartLayout layout) =>
      update(symbol, (_) => layout);

  @override
  Future<Result<void>> update(
    String symbol,
    ChartLayout Function(ChartLayout current) change,
  ) {
    final name = _name(symbol);
    return _enqueue(name, () async {
      final current = await _read(name, ChartLayout.fromJson, ChartLayout());
      return _write(name, change(current).toJson());
    });
  }

  Future<Result<void>> _enqueue(
    String name,
    Future<Result<void>> Function() write,
  ) {
    final next = (_writes[name] ?? Future.value(const Success<void>(null)))
        .then((_) => write());
    _writes[name] = next;
    return next;
  }

  Future<Result<void>> _write(String name, Map<String, Object?> json) async {
    try {
      await AtomicJsonFile(directory, name).write(json);
      _memory[name] = json;
      return const Success(null);
    } on Object {
      reporter.log('chart_write_failed', {'file': name});
      return const Failure(StorageError('Chart storage write failed'));
    }
  }

  @override
  Future<ChartPrefs> loadPrefs() async {
    await _writes[prefsName];
    return _read(prefsName, ChartPrefs.fromJson, const ChartPrefs());
  }

  @override
  Future<Result<void>> savePrefs(ChartPrefs prefs) =>
      _enqueue(prefsName, () => _write(prefsName, prefs.toJson()));

  @override
  Future<void> clearAll() async {
    await Future.wait(_writes.values);
    _writes.clear();
    _memory.clear();
    final dir = await directory;
    if (dir == null || !await dir.exists()) return;
    await for (final file in dir.list()) {
      final name = file.uri.pathSegments.last;
      if (name.startsWith('chart.') &&
          (name.endsWith('.json') || name.endsWith('.json.tmp'))) {
        await file.delete();
      }
    }
  }
}
