import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/application/drawings/drawings_state.dart';
import 'package:stock_pulse/features/chart/domain/chart_prefs.dart';
import 'package:stock_pulse/features/chart/domain/chart_state.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/drawing_geometry.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

void main() {
  test(
    'chart preferences round-trip and copies preserve every display setting',
    () {
      const prefs = ChartPrefs();
      final changed = prefs.copyWith(
        range: ChartRange.m1,
        interval: CandleInterval.d1,
        type: ChartType.line,
        logScale: true,
        gridlines: false,
      );
      expect(ChartPrefs.fromJson(changed.toJson()), changed);
      expect(changed.copyWith().hashCode, changed.hashCode);
      expect(changed, isNot(prefs));
      expect(
        () => ChartPrefs.fromJson({'schemaVersion': 999}),
        throwsFormatException,
      );
      final state = ChartState(
        range: changed.range,
        interval: changed.interval,
        type: changed.type,
      ).copyWith(crosshairIndex: 10);
      expect(state.copyWith(), state);
      expect(state.copyWith().hashCode, state.hashCode);
      expect(state.copyWith(crosshairIndex: null), isNot(state));
    },
  );
  test('drawing state keeps anchors and selection immutable across copies', () {
    final anchor = DrawingAnchor(time: DateTime.utc(2026), price: 100);
    final state = DrawingsState(
      mode: DrawingKind.trendLine,
      pendingAnchor: anchor,
      selectedId: 'one',
      atLimit: true,
      saved: false,
    );
    expect(state.copyWith(), state);
    expect(state.copyWith().hashCode, state.hashCode);
    expect(
      state.copyWith(mode: null, pendingAnchor: null, selectedId: null),
      isNot(state),
    );
    expect(
      () => state.drawings.add(
        Drawing(id: 'one', kind: DrawingKind.horizontal, start: anchor),
      ),
      throwsUnsupportedError,
    );
    final geometry = DrawingGeometry(
      first: anchor.time,
      last: anchor.time.add(const Duration(days: 1)),
      low: 90,
      high: 110,
      width: 300,
      height: 200,
    );
    final same = DrawingGeometry(
      first: geometry.first,
      last: geometry.last,
      low: geometry.low,
      high: geometry.high,
      width: geometry.width,
      height: geometry.height,
    );
    expect(same, geometry);
    expect(same.hashCode, geometry.hashCode);
    expect(
      () => DrawingGeometry(
        first: anchor.time,
        last: anchor.time,
        low: 0,
        high: 1,
        width: 100,
        height: 100,
      ),
      throwsArgumentError,
    );
  });
}
