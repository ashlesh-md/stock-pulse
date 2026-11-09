import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/chart/application/studies/studies_controller.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/chart/domain/studies_store.dart';

import '../../../helpers/fake_crash_reporter.dart';

class Store implements StudiesStore {
  List<StudySpec> saved = [];
  bool failWrite = false;
  bool failRead = false;
  @override
  Future<List<StudySpec>> read(String id) async {
    if (failRead) throw StateError('corrupt');
    return saved;
  }

  @override
  Future<void> write(String id, List<StudySpec> studies) async {
    if (failWrite) throw StateError('disk full');
    saved = studies;
  }
}

void main() {
  test(
    'third lower pane is refused while a price-overlay study can be added',
    () {
      final lowerPanes = [
        const StudySpec(kind: StudyKind.rsi),
        const StudySpec(kind: StudyKind.macd),
      ];
      expect(
        StudiesController.canAdd(
          lowerPanes,
          const StudySpec(kind: StudyKind.rsi, period: 7),
        ),
        isFalse,
      );
      expect(
        StudiesController.canAdd(
          lowerPanes,
          const StudySpec(kind: StudyKind.sma, period: 20),
        ),
        isTrue,
      );
    },
  );

  test(
    'four study limit, duplicate prevention, persisted remove and undo',
    () async {
      final store = Store();
      final container = ProviderContainer.test(
        overrides: [
          studiesStoreProvider.overrideWithValue(store),
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        ],
      );
      final provider = studiesControllerProvider('TCS');
      final controller = container.read(provider.notifier);
      await pumpEventQueue();
      for (final kind in StudyKind.values.take(4)) {
        expect(controller.add(StudySpec(kind: kind)), isTrue);
      }
      expect(controller.add(const StudySpec(kind: StudyKind.macd)), isFalse);
      controller.remove(1);
      expect(container.read(provider), hasLength(3));
      final feedback = container.read(feedbackControllerProvider)!;
      container
          .read(feedbackControllerProvider.notifier)
          .actionTapped(feedback);
      await pumpEventQueue();
      expect(container.read(provider), hasLength(4));
      expect(container.read(provider)[1].kind, StudyKind.ema);
      expect(store.saved, container.read(provider));
      expect(controller.add(const StudySpec(kind: StudyKind.sma)), isFalse);
    },
  );

  test(
    'failed study persistence is reported without breaking the controller',
    () async {
      final store = Store()..failWrite = true;
      final reporter = FakeCrashReporter();
      final container = ProviderContainer.test(
        overrides: [
          studiesStoreProvider.overrideWithValue(store),
          crashReporterProvider.overrideWithValue(reporter),
        ],
      );
      final controller = container.read(
        studiesControllerProvider('TCS').notifier,
      );
      await pumpEventQueue();
      expect(controller.add(const StudySpec(kind: StudyKind.sma)), isTrue);
      await pumpEventQueue();
      expect(reporter.errors.single.reason, 'studies_write');
    },
  );

  test('a failed study read is reported and leaves no studies', () async {
    final reporter = FakeCrashReporter();
    final container = ProviderContainer.test(
      overrides: [
        studiesStoreProvider.overrideWithValue(Store()..failRead = true),
        crashReporterProvider.overrideWithValue(reporter),
      ],
    );
    container.read(studiesControllerProvider('TCS'));
    await pumpEventQueue();

    expect(container.read(studiesControllerProvider('TCS')), isEmpty);
    expect(reporter.errors.single.reason, 'studies_read');
  });
}
