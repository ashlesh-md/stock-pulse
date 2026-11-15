import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/chart/data/local_chart_store.dart';
import 'package:stock_pulse/features/chart/domain/chart_store.dart';

final chartDirectoryProvider = Provider<Future<Directory>?>(
  (ref) => kIsWeb ? null : getApplicationSupportDirectory(),
);
final chartStoreProvider = Provider<ChartStore>(
  (ref) => LocalChartStore(
    ref.watch(chartDirectoryProvider),
    ref.watch(crashReporterProvider),
  ),
);
