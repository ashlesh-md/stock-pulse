import 'dart:async';

/// Runs one resync at a time: asks the server for snapshots, reloads every
/// registered repository over REST, then reports [completed].
///
/// Gaps that arrive while a resync runs join it instead of starting another.
class ResyncCoordinator {
  ResyncCoordinator(this._sendResync);

  final void Function() _sendResync;
  final _reloaders = <Future<void> Function()>[];
  final _completed = StreamController<void>.broadcast();
  final _started = StreamController<void>.broadcast();
  Future<void>? _running;

  /// Fires once per finished resync.
  Stream<void> get completed => _completed.stream;

  /// Fires once per resync, before the reloaders run.
  Stream<void> get started => _started.stream;

  bool get isRunning => _running != null;

  /// Adds [reload]; call the returned function to remove it.
  void Function() register(Future<void> Function() reload) {
    _reloaders.add(reload);
    return () => _reloaders.remove(reload);
  }

  /// A `seq` gap: sends one `resync` op and reloads.
  Future<void> onGap() => _run(sendOp: true);

  /// A new session: the server sends fresh snapshots on subscribe, so only
  /// the REST reloads run.
  Future<void> onReconnect() => _run(sendOp: false);

  Future<void> _run({required bool sendOp}) =>
      _running ??= _resync(sendOp: sendOp).whenComplete(() => _running = null);

  Future<void> _resync({required bool sendOp}) async {
    if (sendOp) _sendResync();
    if (!_started.isClosed) _started.add(null);
    await Future.wait([
      for (final reload in _reloaders.toList())
        reload().catchError((Object _) {}),
    ]);
    if (!_completed.isClosed) _completed.add(null);
  }

  Future<void> dispose() async {
    _reloaders.clear();
    await Future.wait([_completed.close(), _started.close()]);
  }
}
