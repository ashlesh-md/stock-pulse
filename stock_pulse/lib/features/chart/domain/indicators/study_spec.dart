import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';

class StudySpec {
  const StudySpec({
    required this.kind,
    this.period = 14,
    this.deviations = 2,
    this.fast = 12,
    this.slow = 26,
    this.signal = 9,
  });
  final StudyKind kind;
  final int period, fast, slow, signal;
  final double deviations;
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'period': period,
    'deviations': deviations,
    'fast': fast,
    'slow': slow,
    'signal': signal,
  };
  factory StudySpec.fromJson(Map<String, Object?> json) => StudySpec(
    kind: StudyKind.values.byName(json['kind']! as String),
    period: json['period']! as int,
    deviations: (json['deviations']! as num).toDouble(),
    fast: json['fast']! as int,
    slow: json['slow']! as int,
    signal: json['signal']! as int,
  );
  @override
  bool operator ==(Object other) =>
      other is StudySpec &&
      other.kind == kind &&
      other.period == period &&
      other.deviations == deviations &&
      other.fast == fast &&
      other.slow == slow &&
      other.signal == signal;
  @override
  int get hashCode => Object.hash(kind, period, deviations, fast, slow, signal);
}
