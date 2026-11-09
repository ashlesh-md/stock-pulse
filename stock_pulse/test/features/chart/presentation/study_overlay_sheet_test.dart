import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_calculator.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/chart/domain/studies_store.dart';
import 'package:stock_pulse/features/chart/presentation/studies/studies_sheet.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_overlay_layer.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_painter.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

import '../../../helpers/fake_crash_reporter.dart';
import '../../../helpers/sp_app.dart';

class _Store implements StudiesStore {
  _Store(this.saved);
  List<StudySpec> saved;
  @override
  Future<List<StudySpec>> read(String instrumentId) async => saved;
  @override
  Future<void> write(String instrumentId, List<StudySpec> studies) async =>
      saved = studies;
}

Candle _c(int i) => Candle(
  start: DateTime.utc(2026).add(Duration(minutes: i)),
  open: 100.0 + i,
  high: 102.0 + i,
  low: 99.0 + i,
  close: 101.0 + i,
  volume: 10,
);

Future<void> _openSheet(WidgetTester tester, _Store store) async {
  await tester.pumpWidget(
    spApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showStudiesSheet(context, 'TCS'),
          child: const Text('Open'),
        ),
      ),
      overrides: [
        studiesStoreProvider.overrideWithValue(store),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
      ],
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the period slider sets the period of the added study', (
    tester,
  ) async {
    final store = _Store([]);
    await _openSheet(tester, store);
    await tester.drag(find.byType(Slider), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(store.saved.single.period, 2);
  });

  testWidgets('a third lower pane is refused with the pane limit message', (
    tester,
  ) async {
    final store = _Store(const [
      StudySpec(kind: StudyKind.rsi),
      StudySpec(kind: StudyKind.macd),
    ]);
    await _openSheet(tester, store);
    await tester.tap(find.text('SMA').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('RSI').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('price overlays draw SMA and intraday VWAP, not lower panes', (
    tester,
  ) async {
    final candles = [for (var i = 0; i < 40; i++) _c(i)];
    const specs = [
      StudySpec(kind: StudyKind.sma, period: 5),
      StudySpec(kind: StudyKind.vwap),
      StudySpec(kind: StudyKind.rsi),
    ];
    final series = StudyCalculator().calculate(candles, specs);
    await tester.pumpWidget(
      spApp(
        SizedBox(
          width: 400,
          height: 300,
          child: StudyOverlayLayer(
            candles: candles,
            interval: CandleInterval.m1,
            type: ChartType.candles,
            series: series,
            candleWidth: 8,
            offset: 0,
          ),
        ),
      ),
    );
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<StudyPainter>()
        .single;
    expect(painter.priceOverlay, isTrue);
    expect(painter.lines, hasLength(2));
  });
}
