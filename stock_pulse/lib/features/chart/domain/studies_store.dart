import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';

abstract interface class StudiesStore {
  Future<List<StudySpec>> read(String instrumentId);
  Future<void> write(String instrumentId, List<StudySpec> studies);
}
