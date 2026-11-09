import 'dart:async';

import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/data/socket_config.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';

/// In-memory [MarketSocket]: records every holder and lets a test push
/// frames, gaps and status changes. No network, no timers.
class FakeMarketSocket implements MarketSocket {
  FakeMarketSocket({this._status = const SocketConnecting(0)});

  final _statusController = StreamController<SocketStatus>.broadcast(
    sync: true,
  );
  final _messages = StreamController<Map<String, Object?>>.broadcast(
    sync: true,
  );
  final _resync = StreamController<void>.broadcast(sync: true);
  final _resyncStarted = StreamController<void>.broadcast(sync: true);
  final _resyncCompleted = StreamController<void>.broadcast(sync: true);
  final _frames = StreamController<SocketFrame>.broadcast(sync: true);
  SocketStatus _status;
  DateTime? _lastFrameAt;

  /// Every holder ever created, in order; check `isCancelled` on them.
  final List<SocketSubscription> quoteSubs = [];
  final List<ChainSubscription> chainSubs = [];
  final List<AccountSubscription> accountSubs = [];
  final List<Future<void> Function()> _resyncReloaders = [];
  bool started = false;
  bool paused = false;
  bool disposed = false;
  int pauseCount = 0;
  int resumeCount = 0;

  /// Quote ids with at least one live holder.
  Set<String> get activeQuoteIds => {
    for (final s in quoteSubs)
      if (!s.isCancelled) ...s.symbols,
  };

  /// Pushes one decoded frame to `messages`.
  void emit(Map<String, Object?> frame, {DateTime? at}) {
    _lastFrameAt = at ?? DateTime.now();
    _messages.add(frame);
  }

  /// A sequence gap was detected.
  void emitResyncNeeded() {
    _resync.add(null);
    _resyncStarted.add(null);
    unawaited(
      Future.wait([for (final reload in _resyncReloaders) reload()]).then((_) {
        _resyncCompleted.add(null);
      }),
    );
  }

  void emitReconnect() {
    _resyncStarted.add(null);
    unawaited(
      Future.wait([for (final reload in _resyncReloaders) reload()]).then((_) {
        _resyncCompleted.add(null);
      }),
    );
  }

  void setStatus(SocketStatus status) {
    _status = status;
    _statusController.add(status);
  }

  @override
  SocketConfig get config => const SocketConfig();

  @override
  SocketStatus get status => _status;

  @override
  Stream<SocketStatus> get statusChanges => _statusController.stream;

  @override
  Stream<Map<String, Object?>> get messages => _messages.stream;

  @override
  Stream<void> get resyncNeeded => _resync.stream;

  @override
  Stream<void> get resyncStarted => _resyncStarted.stream;

  @override
  Stream<void> get resyncCompleted => _resyncCompleted.stream;

  @override
  void Function() registerResyncReloader(Future<void> Function() reload) {
    _resyncReloaders.add(reload);
    return () => _resyncReloaders.remove(reload);
  }

  @override
  Stream<SocketFrame> get frames => _frames.stream;

  @override
  DateTime? get lastFrameAt => _lastFrameAt;

  @override
  void start() => started = true;

  @override
  SocketSubscription subscribeQuotes(
    Iterable<String> ids,
    FeedMode mode, {
    int throttleMs = 250,
  }) {
    final sub = SocketSubscription(ids, mode, throttleMs: throttleMs);
    quoteSubs.add(sub);
    return sub;
  }

  @override
  ChainSubscription subscribeChain(ChainRequest req) {
    final sub = ChainSubscription(req);
    chainSubs.add(sub);
    return sub;
  }

  @override
  AccountSubscription subscribeAccount({
    bool orders = true,
    bool alerts = true,
  }) {
    final sub = AccountSubscription(orders: orders, alerts: alerts);
    accountSubs.add(sub);
    return sub;
  }

  @override
  void pause() {
    if (!paused) pauseCount++;
    paused = true;
  }

  @override
  void resume() {
    if (paused) resumeCount++;
    paused = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _statusController.close();
    await _messages.close();
    await _resync.close();
    await _resyncStarted.close();
    await _resyncCompleted.close();
    await _frames.close();
  }
}
