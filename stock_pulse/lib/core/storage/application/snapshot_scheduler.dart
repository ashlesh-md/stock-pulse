import 'dart:async';

import 'package:stock_pulse/core/storage/domain/snapshot.dart';
import 'package:stock_pulse/core/storage/domain/snapshot_store.dart';

/// Decides when `snapshot.json` is written:
///
/// | Trigger | Saves when |
/// |---|---|
/// | [onHide] | live data was seen since start |
/// | every [interval] while shown | dirty and live data seen |
/// | `resyncCompleted` | the network is live |
///
/// "Live data seen" stops an offline start from rewriting the old cache
/// with a newer `savedAt`, which would stretch the 7-day rule.
class SnapshotScheduler {
  SnapshotScheduler({
    required this._store,
    required this._isDirty,
    required this._capture,
    required this._hasLiveData,
    required this._isLive,
    required Stream<void> resyncCompleted,
    this.interval = const Duration(seconds: 30),
  }) {
    _resync = resyncCompleted.listen((_) {
      if (_isLive()) _save();
    });
  }

  final SnapshotStore _store;
  final bool Function() _isDirty;
  final Snapshot Function() _capture;
  final bool Function() _hasLiveData;
  final bool Function() _isLive;
  final Duration interval;

  late final StreamSubscription<void> _resync;
  Timer? _timer;
  bool _seenLive = false;

  bool get _liveDataSeen => _seenLive = _seenLive || _hasLiveData();

  /// App shown (and once at shell start): starts the periodic save.
  void onShow() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      if (_liveDataSeen && _isDirty()) _save();
    });
  }

  /// App hidden: stops the timer and saves the latest state.
  void onHide() {
    _timer?.cancel();
    _timer = null;
    if (_liveDataSeen) _save();
  }

  void _save() => unawaited(_store.saveNow(_capture()));

  void dispose() {
    _timer?.cancel();
    unawaited(_resync.cancel());
  }
}
