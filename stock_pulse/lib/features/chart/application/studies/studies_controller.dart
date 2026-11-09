import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/di/l10n_providers.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_catalog.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';

class StudiesController extends Notifier<List<StudySpec>> {
  static const maxStudies = 4;
  static const maxLowerPanes = 2;
  StudiesController(this.instrumentId);
  final String instrumentId;
  int _revision = 0;
  ({StudySpec spec, int index, String key})? _removed;
  Future<void> _write = Future.value();
  @override
  List<StudySpec> build() {
    final sub = ref.read(feedbackControllerProvider.notifier).replies.listen((
      reply,
    ) {
      final removed = _removed;
      if (removed == null ||
          reply.key != removed.key ||
          reply.actionId != 'undo' ||
          !canAdd(state, removed.spec)) {
        return;
      }
      if (!state.contains(removed.spec)) {
        final next = [...state]
          ..insert(removed.index.clamp(0, state.length), removed.spec);
        state = List.unmodifiable(next);
        _save();
      }
      _removed = null;
    });
    ref.onDispose(sub.cancel);
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    final revision = _revision;
    try {
      final values = await ref.read(studiesStoreProvider).read(instrumentId);
      if (!ref.mounted || revision != _revision) return;
      state = List.unmodifiable(values);
    } on Object catch (error, stack) {
      if (ref.mounted) {
        ref
            .read(crashReporterProvider)
            .recordError(error, stack, reason: 'studies_read');
      }
    }
  }

  bool add(StudySpec spec) {
    if (!canAdd(state, spec)) return false;
    state = List.unmodifiable([...state, spec]);
    _save();
    ref.read(analyticsProvider).log(Events.studyAdded(spec.kind.name));
    return true;
  }

  static bool canAdd(List<StudySpec> studies, StudySpec spec) {
    if (studies.length >= maxStudies || studies.contains(spec)) return false;
    return !StudyCatalog.isLowerPane(spec.kind) ||
        studies.where((study) => StudyCatalog.isLowerPane(study.kind)).length <
            maxLowerPanes;
  }

  void remove(int index) {
    final spec = state[index];
    final key = 'chart.study_removed.$instrumentId.${_revision + 1}';
    _removed = (spec: spec, index: index, key: key);
    state = List.unmodifiable([...state]..removeAt(index));
    _save();
    ref.read(analyticsProvider).log(Events.studyRemoved(spec.kind.name));
    final strings = ref.read(stringsProvider).studies;
    ref
        .read(feedbackControllerProvider.notifier)
        .show(
          FeedbackMessage(
            key: key,
            text: strings.removed,
            actionLabel: strings.undo,
            action: const ReplyToSender('undo'),
          ),
        );
  }

  void _save() {
    _revision++;
    final store = ref.read(studiesStoreProvider);
    final studies = state;
    final reporter = ref.read(crashReporterProvider);
    _write = _write.then((_) => store.write(instrumentId, studies)).onError((
      Object error,
      StackTrace stack,
    ) {
      reporter.recordError(error, stack, reason: 'studies_write');
    });
  }
}
