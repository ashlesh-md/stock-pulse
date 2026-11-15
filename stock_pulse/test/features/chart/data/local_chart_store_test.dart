import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/chart/data/local_chart_store.dart';
import 'package:stock_pulse/features/chart/domain/chart_layout.dart';
import 'package:stock_pulse/features/chart/domain/chart_prefs.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

import '../../../helpers/fake_crash_reporter.dart';

void main() {
  test(
    'unavailable storage returns an empty layout when cleanup also fails',
    () async {
      final reporter = FakeCrashReporter();
      final store = LocalChartStore(
        Future<Directory>.error(const FileSystemException('unavailable')),
        reporter,
      );
      expect(await store.load('TCS'), ChartLayout());
      expect(reporter.logs.map((e) => e.event), [
        'chart_discarded',
        'chart_delete_failed',
      ]);
    },
  );
  late Directory directory;
  late FakeCrashReporter reporter;
  late LocalChartStore store;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('chart-store-');
    reporter = FakeCrashReporter();
    store = LocalChartStore(Future.value(directory), reporter);
  });
  tearDown(() => directory.deleteSync(recursive: true));
  test(
    'S-56 trend and RSI survive restart; symbols remain independent',
    () async {
      final layout = ChartLayout(
        drawings: [
          Drawing(
            id: 'trend',
            kind: DrawingKind.trendLine,
            start: DrawingAnchor(time: DateTime.utc(2026), price: 100),
            end: DrawingAnchor(time: DateTime.utc(2026, 1, 2), price: 200),
          ),
        ],
        studies: const [StudySpec(kind: StudyKind.rsi)],
      );
      expect(await store.save('RELIANCE', layout), isA<Success<void>>());
      final restored = LocalChartStore(Future.value(directory), reporter);
      expect(await restored.load('RELIANCE'), layout);
      expect(await restored.load('TCS'), ChartLayout());
      expect(
        directory.listSync().where((f) => f.path.endsWith('.tmp')),
        isEmpty,
      );
    },
  );
  test(
    'S-56 F6 corrupt and unknown-schema layouts are deleted and logged once',
    () async {
      for (final raw in ['{"schemaVersion":', '{"schemaVersion":999}']) {
        final file = File('${directory.path}/chart.RELIANCE.json');
        await file.writeAsString(raw);
        expect(await store.load('RELIANCE'), ChartLayout());
        expect(await file.exists(), isFalse);
      }
      expect(
        reporter.logs.where((e) => e.event == 'chart_discarded'),
        hasLength(2),
      );
    },
  );
  test('S-56 F11 failed write returns Failure and next save retries', () async {
    final unavailable = Directory('${directory.path}/later');
    final failing = LocalChartStore(Future.value(unavailable), reporter);
    expect(await failing.save('TCS', ChartLayout()), isA<Failure<void>>());
    await unavailable.create();
    expect(await failing.save('TCS', ChartLayout()), isA<Success<void>>());
  });
  test(
    'S-56 preferences survive restart and clearAll removes only chart files',
    () async {
      const prefs = ChartPrefs(
        range: ChartRange.m1,
        interval: CandleInterval.d1,
        type: ChartType.line,
        logScale: true,
        gridlines: false,
      );
      await store.savePrefs(prefs);
      await store.save('TCS', ChartLayout());
      final restored = LocalChartStore(Future.value(directory), reporter);
      expect(await restored.loadPrefs(), prefs);
      await File('${directory.path}/prefs.json').writeAsString('{}');
      await restored.clearAll();
      expect(directory.listSync().map((f) => f.path.split('/').last), [
        'prefs.json',
      ]);
      expect(await restored.loadPrefs(), const ChartPrefs());
    },
  );
  test(
    'S-56 simultaneous study and drawing updates preserve both edits',
    () async {
      await Future.wait([
        store.update(
          'TCS',
          (layout) => ChartLayout(
            drawings: layout.drawings,
            studies: const [StudySpec(kind: StudyKind.rsi)],
          ),
        ),
        store.update(
          'TCS',
          (layout) => ChartLayout(
            studies: layout.studies,
            drawings: [
              Drawing(
                id: 'line',
                kind: DrawingKind.horizontal,
                start: DrawingAnchor(time: DateTime.utc(2026), price: 100),
              ),
            ],
          ),
        ),
      ]);
      final layout = await store.load('TCS');
      expect(layout.studies, hasLength(1));
      expect(layout.drawings, hasLength(1));
    },
  );
}
