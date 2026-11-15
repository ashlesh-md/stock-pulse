import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/chart/domain/chart_layout.dart';
import 'package:stock_pulse/features/chart/domain/chart_prefs.dart';
import 'package:stock_pulse/features/chart/domain/chart_store.dart';

class MemoryChartStore implements ChartStore {
  ChartLayout layout = ChartLayout();
  ChartPrefs prefs = const ChartPrefs();
  int writes = 0;
  int prefsWrites = 0;
  bool fail = false;
  @override
  Future<ChartLayout> load(String symbol) async => layout;
  @override
  Future<Result<void>> save(String symbol, ChartLayout next) async {
    writes++;
    if (fail) return const Failure(NetworkError());
    layout = next;
    return const Success(null);
  }

  @override
  Future<Result<void>> update(
    String symbol,
    ChartLayout Function(ChartLayout) change,
  ) => save(symbol, change(layout));
  @override
  Future<ChartPrefs> loadPrefs() async => prefs;

  @override
  Future<Result<void>> savePrefs(ChartPrefs next) async {
    prefsWrites++;
    if (fail) return const Failure(NetworkError());
    prefs = next;
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
