import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';

/// Per-symbol user content persisted by the chart store.
@immutable
class ChartLayout {
  ChartLayout({
    Iterable<Drawing> drawings = const [],
    Iterable<StudySpec> studies = const [],
  }) : drawings = List.unmodifiable(drawings),
       studies = List.unmodifiable(studies);

  final List<Drawing> drawings;
  final List<StudySpec> studies;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'drawings': [for (final drawing in drawings) drawing.toJson()],
    'studies': [for (final study in studies) study.toJson()],
  };

  factory ChartLayout.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported chart layout version');
    }
    return ChartLayout(
      drawings: [
        for (final value in json['drawings']! as List)
          Drawing.fromJson(Map<String, Object?>.from(value as Map)),
      ],
      studies: [
        for (final value in json['studies']! as List)
          StudySpec.fromJson(Map<String, Object?>.from(value as Map)),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChartLayout &&
      listEquals(other.drawings, drawings) &&
      listEquals(other.studies, studies);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(drawings), Object.hashAll(studies));
}
