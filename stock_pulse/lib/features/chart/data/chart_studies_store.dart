import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/chart/domain/chart_layout.dart';
import 'package:stock_pulse/features/chart/domain/chart_store.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/chart/domain/studies_store.dart';

class ChartStudiesStore implements StudiesStore {
  ChartStudiesStore(this.store);
  final ChartStore store;
  @override
  Future<List<StudySpec>> read(String instrumentId) async =>
      (await store.load(instrumentId)).studies;
  @override
  Future<void> write(String instrumentId, List<StudySpec> studies) async {
    final result = await store.update(
      instrumentId,
      (layout) => ChartLayout(drawings: layout.drawings, studies: studies),
    );
    if (result case Failure(:final error)) throw error;
  }
}
