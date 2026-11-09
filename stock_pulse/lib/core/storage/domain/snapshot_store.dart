import 'package:stock_pulse/core/storage/domain/snapshot.dart';

/// Writes `snapshot.json`. `SnapshotScheduler` decides when.
abstract interface class SnapshotStore {
  /// Watchlist edit, position or holding change. Sets a flag only; LTP ticks
  /// never call it. Callers: `MarketRepository.setWatchlist`, the portfolio
  /// repository.
  void markStructuralDirty();

  Future<void> saveNow(Snapshot s);

  /// Deletes the file and resets the flags. Prefs are untouched.
  Future<void> clear();
}
