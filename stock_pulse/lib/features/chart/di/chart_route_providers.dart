import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/chart/domain/chart_selection.dart';

/// Optional deep-link settings consumed before the stock detail request starts.
final initialChartSelectionProvider = Provider.family<ChartSelection?, String>(
  (ref, instrumentId) => null,
);
