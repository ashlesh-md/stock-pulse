import 'package:stock_pulse/features/chart/domain/indicators/indicator.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_series.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

class StudyCalculator {
  final _engines = <StudySpec, Indicator>{};
  List<Candle> _previous = const [];
  List<StudySpec> _previousSpecs = const [];
  Map<StudySpec, StudySeries> _lastResult = const {};
  Map<StudySpec, StudySeries> calculate(
    List<Candle> candles,
    List<StudySpec> specs,
  ) {
    if (identical(_previous, candles) && _sameSpecs(_previousSpecs, specs)) {
      return _lastResult;
    }
    final samePrefix =
        _previous.length >= 2 &&
        candles.length >= _previous.length &&
        identical(
          _previous[_previous.length - 2],
          candles[_previous.length - 2],
        );
    final append =
        candles.length == _previous.length + 1 &&
        _previous.isNotEmpty &&
        identical(_previous.last, candles[_previous.length - 1]);
    _engines.removeWhere((spec, _) => !specs.contains(spec));
    final result = <StudySpec, StudySeries>{};
    for (final spec in specs) {
      final existing = _engines[spec];
      final engine = _engines.putIfAbsent(spec, () => Indicator(spec));
      if (identical(_previous, candles) && existing != null) {
        result[spec] = engine.series;
      } else if (existing != null &&
          candles.isNotEmpty &&
          (append || (samePrefix && candles.length == _previous.length))) {
        result[spec] = engine.update(candles.last, append: append);
      } else {
        result[spec] = engine.build(candles);
      }
    }
    _previous = candles;
    _previousSpecs = List.unmodifiable(specs);
    _lastResult = Map.unmodifiable(result);
    return _lastResult;
  }

  bool _sameSpecs(List<StudySpec> a, List<StudySpec> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
