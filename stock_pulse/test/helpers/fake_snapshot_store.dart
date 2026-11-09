import 'package:stock_pulse/core/storage/domain/snapshot.dart';
import 'package:stock_pulse/core/storage/domain/snapshot_store.dart';

/// Records calls. Override with
/// `snapshotStoreProvider.overrideWithValue(FakeSnapshotStore())`.
class FakeSnapshotStore implements SnapshotStore {
  final saved = <Snapshot>[];
  int structuralDirtyMarks = 0;
  int clears = 0;

  /// True after [markStructuralDirty] until the next [saveNow] or [clear].
  bool get dirty => _dirty;
  bool _dirty = false;

  @override
  void markStructuralDirty() {
    structuralDirtyMarks++;
    _dirty = true;
  }

  @override
  Future<void> saveNow(Snapshot s) async {
    saved.add(s);
    _dirty = false;
  }

  @override
  Future<void> clear() async {
    clears++;
    _dirty = false;
  }
}
