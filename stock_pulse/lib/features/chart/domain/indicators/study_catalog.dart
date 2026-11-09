import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';

/// Supported studies and their initial parameters.
abstract final class StudyCatalog {
  static const defaults = <StudySpec>[
    StudySpec(kind: StudyKind.sma, period: 20),
    StudySpec(kind: StudyKind.ema, period: 9),
    StudySpec(kind: StudyKind.vwap),
    StudySpec(kind: StudyKind.rsi),
    StudySpec(kind: StudyKind.bollinger, period: 20),
    StudySpec(kind: StudyKind.macd, period: 26),
  ];

  static StudySpec defaultFor(StudyKind kind) =>
      defaults.firstWhere((spec) => spec.kind == kind);

  static bool isLowerPane(StudyKind kind) =>
      kind == StudyKind.rsi || kind == StudyKind.macd;
}
