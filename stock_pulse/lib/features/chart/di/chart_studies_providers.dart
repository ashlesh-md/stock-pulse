import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/chart/application/studies/studies_controller.dart';
import 'package:stock_pulse/features/chart/data/chart_studies_store.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/chart/domain/studies_store.dart';

final studiesControllerProvider =
    NotifierProvider.family<StudiesController, List<StudySpec>, String>(
      StudiesController.new,
    );

final studiesStoreProvider = Provider<StudiesStore>(
  (ref) => ChartStudiesStore(ref.watch(chartStoreProvider)),
);
