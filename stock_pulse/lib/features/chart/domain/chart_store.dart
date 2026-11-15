import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/chart/domain/chart_layout.dart';
import 'package:stock_pulse/features/chart/domain/chart_prefs.dart';

abstract interface class ChartStore {
  Future<ChartLayout> load(String symbol);
  Future<Result<void>> save(String symbol, ChartLayout layout);
  Future<Result<void>> update(
    String symbol,
    ChartLayout Function(ChartLayout current) change,
  );
  Future<ChartPrefs> loadPrefs();
  Future<Result<void>> savePrefs(ChartPrefs prefs);
  Future<void> clearAll();
}
