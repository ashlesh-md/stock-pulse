import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/di/l10n_providers.dart';
import 'package:stock_pulse/features/chart/application/drawings/drawings_state.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/domain/chart_layout.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/tick_snap.dart';

class DrawingsController extends Notifier<DrawingsState> {
  DrawingsController(this.instrumentId);
  final String instrumentId;
  Timer? _saveTimer;
  int _revision = 0;
  int _nextId = 0;
  Future<void> _writes = Future.value();

  @override
  DrawingsState build() {
    unawaited(_load());
    ref.onDispose(() => _saveTimer?.cancel());
    return DrawingsState();
  }

  Future<void> _load() async {
    final revision = _revision;
    final layout = await ref.read(chartStoreProvider).load(instrumentId);
    if (!ref.mounted || revision != _revision) return;
    state = state.copyWith(drawings: layout.drawings);
  }

  void start(DrawingKind? kind) {
    state = state.copyWith(
      mode: kind,
      pendingAnchor: null,
      selectedId: null,
      atLimit: kind != null && state.drawings.length >= 20,
    );
  }

  void place(DrawingAnchor anchor, {required double tickSize}) {
    final mode = state.mode;
    if (mode == null || state.atLimit) return;
    final point = DrawingAnchor(
      time: anchor.time,
      price: snapToTick(anchor.price, tickSize),
    );
    if (mode != DrawingKind.horizontal && state.pendingAnchor == null) {
      state = state.copyWith(pendingAnchor: point);
      return;
    }
    final drawing = Drawing(
      id: '${DateTime.now().microsecondsSinceEpoch}.${_nextId++}',
      kind: mode,
      start: state.pendingAnchor ?? point,
      end: mode == DrawingKind.horizontal ? null : point,
    );
    state = state.copyWith(
      drawings: [...state.drawings, drawing],
      mode: null,
      pendingAnchor: null,
      selectedId: drawing.id,
    );
    ref.read(analyticsProvider).log(Events.drawingAdded(mode.name));
    _edited();
  }

  void select(String? id) =>
      state = state.copyWith(selectedId: id, mode: null, pendingAnchor: null);

  void moveHandle(
    String id, {
    required bool end,
    required DrawingAnchor anchor,
    required double tickSize,
  }) {
    final point = DrawingAnchor(
      time: anchor.time,
      price: snapToTick(anchor.price, tickSize),
    );
    _replace(
      id,
      (drawing) => Drawing(
        id: drawing.id,
        kind: drawing.kind,
        start: end ? drawing.start : point,
        end: end && drawing.end != null ? point : drawing.end,
      ),
    );
  }

  void moveBody(
    String id, {
    required Duration timeDelta,
    required double priceDelta,
    required double tickSize,
  }) {
    DrawingAnchor move(DrawingAnchor a) => DrawingAnchor(
      time: a.time.add(timeDelta),
      price: snapToTick(a.price + priceDelta, tickSize),
    );
    _replace(
      id,
      (drawing) => Drawing(
        id: drawing.id,
        kind: drawing.kind,
        start: move(drawing.start),
        end: drawing.end == null ? null : move(drawing.end!),
      ),
    );
  }

  void _replace(String id, Drawing Function(Drawing) change) {
    if (!state.drawings.any((d) => d.id == id)) return;
    state = state.copyWith(
      drawings: [for (final d in state.drawings) d.id == id ? change(d) : d],
    );
    _edited();
  }

  void deleteSelected() {
    if (state.selectedId == null) return;
    state = state.copyWith(
      drawings: state.drawings.where((d) => d.id != state.selectedId),
      selectedId: null,
      atLimit: false,
    );
    _edited();
  }

  void _edited() {
    final revision = ++_revision;
    state = state.copyWith(saved: false);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      final layout = ChartLayout(drawings: state.drawings);
      _writes = _writes.then((_) => _save(layout, revision));
    });
  }

  Future<void> _save(ChartLayout layout, int revision) async {
    final result = await ref
        .read(chartStoreProvider)
        .update(
          instrumentId,
          (current) =>
              ChartLayout(drawings: layout.drawings, studies: current.studies),
        );
    if (!ref.mounted) return;
    switch (result) {
      case Success():
        if (_revision == revision) state = state.copyWith(saved: true);
      case Failure():
        ref
            .read(feedbackControllerProvider.notifier)
            .show(
              FeedbackMessage(
                key: 'chart.drawing_save_failed.$instrumentId',
                text: ref.read(stringsProvider).chart.saveFailed,
                kind: FeedbackKind.error,
              ),
            );
    }
  }
}
