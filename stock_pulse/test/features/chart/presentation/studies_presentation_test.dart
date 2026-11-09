import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_series.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/chart/domain/studies_store.dart';
import 'package:stock_pulse/features/chart/presentation/studies/studies_sheet.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_chip_row.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_painter.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_pane_stack.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

import '../../../helpers/fake_crash_reporter.dart';
import '../../../helpers/sp_app.dart';

class _StudiesStore implements StudiesStore {
  _StudiesStore(this.saved);
  List<StudySpec> saved;
  @override
  Future<List<StudySpec>> read(String instrumentId) async => saved;
  @override
  Future<void> write(String instrumentId, List<StudySpec> studies) async {
    saved = studies;
  }
}

void main() {
  testWidgets('RSI lower pane has 30/70 guides and resizes within bounds', (
    tester,
  ) async {
    const rsi = StudySpec(kind: StudyKind.rsi);
    await tester.pumpWidget(
      spApp(
        StudyPaneStack(
          series: {
            rsi: StudySeries(
              lines: {
                'value': [null, 50, 70],
              },
              notEnoughData: false,
            ),
          },
          maxPaneHeight: 120,
        ),
        overrides: [
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final paint = tester.widget<CustomPaint>(
      find
          .byWidgetPredicate(
            (widget) => widget is CustomPaint && widget.painter is StudyPainter,
          )
          .first,
    );
    expect((paint.painter! as StudyPainter).guides, [30, 70]);
    expect(tester.getSize(find.byType(StudyPaneStack)).height, 92);

    await tester.drag(find.byType(GestureDetector).last, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(StudyPaneStack)).height, 132);

    await tester.drag(find.byType(GestureDetector).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(StudyPaneStack)).height, 76);
  });

  testWidgets('study chips explain unsupported VWAP and insufficient history', (
    tester,
  ) async {
    const vwap = StudySpec(kind: StudyKind.vwap);
    const sma = StudySpec(kind: StudyKind.sma, period: 200);
    await tester.pumpWidget(
      spApp(
        StudyChipRow(
          instrumentId: 'TCS',
          interval: CandleInterval.d1,
          series: {
            vwap: StudySeries(
              lines: {
                'value': [null],
              },
              notEnoughData: true,
            ),
            sma: StudySeries(
              lines: {
                'value': [null],
              },
              notEnoughData: true,
            ),
          },
        ),
        overrides: [
          studiesStoreProvider.overrideWithValue(_StudiesStore([vwap, sma])),
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('VWAP: intraday only'), findsOneWidget);
    expect(find.text('Not enough data for SMA(200)'), findsOneWidget);
  });

  testWidgets('study chip removes its study through the controller', (
    tester,
  ) async {
    final store = _StudiesStore([
      const StudySpec(kind: StudyKind.sma, period: 20),
    ]);
    await tester.pumpWidget(
      spApp(
        const StudyChipRow(instrumentId: 'TCS'),
        overrides: [
          studiesStoreProvider.overrideWithValue(store),
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SMA (20)'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove study'));
    await tester.pumpAndSettle();
    expect(find.text('SMA (20)'), findsNothing);
    expect(store.saved, isEmpty);
  });

  testWidgets('study picker adds the selected study and dismisses', (
    tester,
  ) async {
    final store = _StudiesStore([]);
    await tester.pumpWidget(
      spApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStudiesSheet(context, 'TCS'),
              child: const Text('Open studies'),
            ),
          ),
        ),
        overrides: [
          studiesStoreProvider.overrideWithValue(store),
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        ],
      ),
    );
    await tester.tap(find.text('Open studies'));
    await tester.pumpAndSettle();
    expect(find.byType(StudiesSheet), findsOneWidget);

    await tester.tap(find.text('SMA').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('MACD').last);
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(store.saved, [const StudySpec(kind: StudyKind.macd, period: 26)]);
    expect(find.byType(StudiesSheet), findsNothing);
  });

  testWidgets('study picker disables add after reaching the four study limit', (
    tester,
  ) async {
    final store = _StudiesStore(
      StudyKind.values.take(4).map((kind) => StudySpec(kind: kind)).toList(),
    );
    await tester.pumpWidget(
      spApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showStudiesSheet(context, 'NIFTY'),
              child: const Text('Open studies'),
            ),
          ),
        ),
        overrides: [
          studiesStoreProvider.overrideWithValue(store),
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        ],
      ),
    );
    await tester.tap(find.text('Open studies'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      find.text('You can use up to 4 studies. Remove one to add another.'),
      findsOneWidget,
    );
  });

  testWidgets('study panes omit overlays and render RSI and MACD labels', (
    tester,
  ) async {
    const rsi = StudySpec(kind: StudyKind.rsi);
    const macd = StudySpec(kind: StudyKind.macd);
    const sma = StudySpec(kind: StudyKind.sma, period: 20);
    final series = {
      rsi: StudySeries(
        lines: {
          'rsi': [25, 45, 75],
        },
        notEnoughData: false,
      ),
      macd: StudySeries(
        lines: {
          'macd': [-.5, .3, .8],
          'signal': [-.2, .2, .5],
          'histogram': [-.3, .1, .3],
        },
        notEnoughData: false,
      ),
      sma: StudySeries(
        lines: {
          'sma': [10, 11, 12],
        },
        notEnoughData: false,
      ),
    };

    await tester.pumpWidget(spApp(StudyPaneStack(series: series)));
    expect(find.text('RSI (14)'), findsOneWidget);
    expect(find.text('MACD (14)'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StudyPaneStack),
        matching: find.byType(CustomPaint),
      ),
      findsNWidgets(2),
    );
    expect(tester.getSize(find.byType(StudyPaneStack)).height, 184);
  });

  testWidgets('empty and overlay-only series produce no pane', (tester) async {
    const rsi = StudySpec(kind: StudyKind.rsi);
    const sma = StudySpec(kind: StudyKind.sma);
    await tester.pumpWidget(
      spApp(
        StudyPaneStack(
          series: {
            rsi: StudySeries(lines: const {}, notEnoughData: true),
            sma: StudySeries(
              lines: const {
                'sma': [1, 2],
              },
              notEnoughData: false,
            ),
          },
        ),
      ),
    );

    expect(tester.getSize(find.byType(StudyPaneStack)), Size.zero);
  });
}
