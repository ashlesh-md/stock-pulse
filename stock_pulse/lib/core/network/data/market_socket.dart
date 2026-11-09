import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/market_time/domain/server_clock.dart';
import 'package:stock_pulse/core/network/data/backoff.dart';
import 'package:stock_pulse/core/network/data/frame_decoder.dart';
import 'package:stock_pulse/core/network/data/resync_coordinator.dart';
import 'package:stock_pulse/core/network/data/socket_config.dart';
import 'package:stock_pulse/core/network/data/subscription_book.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/core/network/domain/socket_ops.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'market_socket_quote_subscriptions.dart';
part 'market_socket_connection.dart';

class MarketSocket {
  MarketSocket(
    this._uri, {
    WebSocketChannel Function(Uri uri)? connect,
    this.config = const SocketConfig(),
    Random? random,
    this._clock = const SystemClock(),
    this._serverClock,
  }) : _connect = connect ?? WebSocketChannel.connect,
       _random = random ?? Random();

  final Uri _uri;
  final WebSocketChannel Function(Uri) _connect;
  final SocketConfig config;
  final Random _random;
  final Clock _clock;
  final ServerClock? _serverClock;
  final _book = SubscriptionBook();
  final _gaps = SequenceGapDetector();
  DateTime? _lastDataAt;
  late final ResyncCoordinator _resyncCoordinator = ResyncCoordinator(() {
    if (_channel != null) _send(Resync(_book.nextRequestId()));
  });

  final _statusController = StreamController<SocketStatus>.broadcast();
  final _messageController = StreamController<Map<String, Object?>>.broadcast();
  final _frameController = StreamController<SocketFrame>.broadcast();

  WebSocketChannel? _channel;

  WebSocketChannel? _connecting;
  StreamSubscription<dynamic>? _channelSub;

  int _generation = 0;
  int _attempt = 0;
  late DateTime _lastFrameAt = _clock.now();
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  final Map<String, DateTime> _quoteLingerDeadlines = {};
  Timer? _quoteLingerTimer;
  bool _started = false;
  bool _paused = false;
  bool _disposed = false;
  SocketStatus _status = const SocketConnecting(0);

  SocketStatus get status => _status;
  Stream<SocketStatus> get statusChanges => _statusController.stream;
  Stream<Map<String, Object?>> get messages => _messageController.stream;

  /// Fires once per resync (gap or new session), before reloaders run.
  Stream<void> get resyncNeeded => _resyncCoordinator.started;
  Stream<void> get resyncCompleted => _resyncCoordinator.completed;
  Stream<void> get resyncStarted => _resyncCoordinator.started;
  void Function() registerResyncReloader(Future<void> Function() reload) =>
      _resyncCoordinator.register(reload);

  /// Last data frame. While connected with no quote or chain subscription
  /// the server owes nothing, so silence then is not staleness and this
  /// reads as now.
  DateTime? get lastFrameAt => _status is SocketConnected && !_book.expectsData
      ? _clock.now()
      : _lastDataAt;
  Stream<SocketFrame> get frames => _frameController.stream;

  SocketSubscription subscribeQuotes(
    Iterable<String> ids,
    FeedMode mode, {
    int throttleMs = 250,
  }) =>
      MarketSocketQuoteSubscriptions(this)
          .subscribe(ids, mode, throttleMs: throttleMs);

  void start() {
    if (_started || _disposed) return;
    _started = true;
    unawaited(_open());
  }

  ChainSubscription subscribeChain(ChainRequest req) {
    final holder = ChainSubscription(
      req,
      onRange: (_, _, _) => _sync(() {}),
      onCancel: (h) => _sync(() => _book.removeChain(h)),
    );
    _sync(() => _book.addChain(holder));
    return holder;
  }

  AccountSubscription subscribeAccount({
    bool orders = true,
    bool alerts = true,
  }) {
    final holder = AccountSubscription(
      orders: orders,
      alerts: alerts,
      onCancel: (h) => _sync(() => _book.removeAccount(h)),
    );
    _sync(() => _book.addAccount(holder));
    return holder;
  }

  void pause() {
    if (_paused || _disposed) return;
    _paused = true;
    _reconnectTimer?.cancel();
    _closeChannel(1000, 'app paused');
    _setStatus(const SocketPaused());
  }

  void resume() {
    if (!_paused || _disposed) return;
    _paused = false;
    _attempt = 0;
    if (_started) unawaited(_open());
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _quoteLingerTimer?.cancel();
    _quoteLingerTimer = null;
    _quoteLingerDeadlines.clear();
    _closeChannel(1000, 'dispose');
    await Future.wait([
      _statusController.close(),
      _messageController.close(),
      _resyncCoordinator.dispose(),
      _frameController.close(),
      _resyncCoordinator.dispose(),
    ]);
  }

  Future<void> _open() async {
    final generation = ++_generation;
    _setStatus(SocketConnecting(_attempt));
    final channel = _connect(_uri);
    _connecting = channel;
    try {
      await channel.ready.timeout(config.connectTimeout);
    } on Exception {
      if (generation != _generation) return;
      _connecting = null;
      channel.sink.close().ignore();
      _onClosed(generation, 'connect failed');
      return;
    }
    if (generation != _generation) {
      channel.sink.close().ignore();
      return;
    }
    _connecting = null;
    _channel = channel;
    _gaps.reset();
    _book.forgetServerState();
    _lastFrameAt = _clock.now();
    _channelSub = channel.stream.listen(
      (data) => _onFrame(generation, data),
      onDone: () => _onClosed(generation, _closeReason(channel)),
      onError: (Object _) => _onClosed(generation, 'socket error'),
    );
    _heartbeat = Timer.periodic(config.pingInterval, (_) => _beat(generation));
    _sync(() {});
  }

  void _onFrame(int generation, Object? data) {
    if (generation != _generation) return;
    _lastFrameAt = _clock.now();
    final text = frameText(data);
    _log(outgoing: false, text);
    final msg = decodeFrame(text);
    if (msg == null) return;
    switch (msg['type']) {
      case 'welcome':
        _lastDataAt = _clock.now();
        _onWelcome(msg);
      case 'pong':
        _onPong(msg);
      case 'ticks' ||
          'order' ||
          'ka' ||
          'clock' ||
          'chain' ||
          'position' ||
          'holding' ||
          'funds' ||
          'settlement' ||
          'alert':
        _lastDataAt = _clock.now();
        if (_gaps.isGap(msg['seq'])) {
          unawaited(_resyncCoordinator.onGap());
        }
        _messageController.add(msg);
    }
  }

  void _beat(int generation) {
    if (generation != _generation) return;
    if (_clock.now().difference(_lastFrameAt) > config.staleAfter) {
      _onClosed(generation, 'no data for ${config.staleAfter.inSeconds}s');
      return;
    }
    _send(Ping(_clock.now().millisecondsSinceEpoch));
  }

  void _closeChannel(int code, String reason) {
    _heartbeat?.cancel();
    unawaited(_channelSub?.cancel());
    // Not awaited: a half-open socket may never finish the close handshake.
    _channel?.sink.close(code, reason).ignore();
    _connecting?.sink.close().ignore();
    _channel = null;
    _connecting = null;
    _generation++;
  }

  void _sync(void Function() change) {
    change();
    if (_channel == null) return;
    final wasIdle = !_book.expectsData;
    _book.pendingOps().forEach(_send);
    if (wasIdle && _book.expectsData && _status is SocketConnected) {
      _lastDataAt = _clock.now();
    }
  }

  void _send(SocketOp op) {
    final text = jsonEncode(op.toJson());
    _log(outgoing: true, text);
    _channel!.sink.add(text);
  }
}
