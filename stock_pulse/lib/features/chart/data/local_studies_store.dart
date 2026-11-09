import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/chart/domain/studies_store.dart';

class LocalStudiesStore implements StudiesStore {
  LocalStudiesStore(this.preferences);
  final SharedPreferencesAsync preferences;
  @override
  Future<List<StudySpec>> read(String instrumentId) async {
    final raw = await preferences.getString('studies.$instrumentId');
    if (raw == null) return const [];
    return (jsonDecode(raw) as List<Object?>)
        .take(4)
        .map((v) => StudySpec.fromJson(v! as Map<String, Object?>))
        .toList();
  }

  @override
  Future<void> write(String instrumentId, List<StudySpec> studies) =>
      preferences.setString(
        'studies.$instrumentId',
        jsonEncode(studies.map((s) => s.toJson()).toList()),
      );
}
