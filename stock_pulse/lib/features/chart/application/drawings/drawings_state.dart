import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';

const _keep = Object();

@immutable
class DrawingsState {
  DrawingsState({
    Iterable<Drawing> drawings = const [],
    this.mode,
    this.pendingAnchor,
    this.selectedId,
    this.atLimit = false,
    this.saved = true,
  }) : drawings = List.unmodifiable(drawings);
  final List<Drawing> drawings;
  final DrawingKind? mode;
  final DrawingAnchor? pendingAnchor;
  final String? selectedId;
  final bool atLimit;
  final bool saved;
  DrawingsState copyWith({
    Iterable<Drawing>? drawings,
    Object? mode = _keep,
    Object? pendingAnchor = _keep,
    Object? selectedId = _keep,
    bool? atLimit,
    bool? saved,
  }) => DrawingsState(
    drawings: drawings ?? this.drawings,
    mode: identical(mode, _keep) ? this.mode : mode as DrawingKind?,
    pendingAnchor: identical(pendingAnchor, _keep)
        ? this.pendingAnchor
        : pendingAnchor as DrawingAnchor?,
    selectedId: identical(selectedId, _keep)
        ? this.selectedId
        : selectedId as String?,
    atLimit: atLimit ?? this.atLimit,
    saved: saved ?? this.saved,
  );
  @override
  bool operator ==(Object other) =>
      other is DrawingsState &&
      listEquals(drawings, other.drawings) &&
      mode == other.mode &&
      pendingAnchor == other.pendingAnchor &&
      selectedId == other.selectedId &&
      atLimit == other.atLimit &&
      saved == other.saved;
  @override
  int get hashCode => Object.hash(
    Object.hashAll(drawings),
    mode,
    pendingAnchor,
    selectedId,
    atLimit,
    saved,
  );
}
