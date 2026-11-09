import 'dart:convert';
import 'dart:math';

import 'package:market_server/src/market_clock.dart';
import 'package:market_server/src/market_engine.dart';
import 'package:market_server/src/ws_chain.dart';
import 'package:market_server/src/ws_gateway.dart';
import 'package:market_server/src/ws_session_ops.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class QuoteSub {
  QuoteSub(this.mode, this.throttleMs);

  FeedMode mode;
  int throttleMs;
  DateTime? lastSentAt;

  /// Last time this id was confirmed (in `ticks` or `ka`).
  DateTime? lastConfirmedAt;
}

class WsSession {
  WsSession(this.id, this.channel, this.gateway)
    : lastHeard = gateway.clock.wallNow();

  final String id;
  final WebSocketChannel channel;
  final WsGateway gateway;

  final Map<String, QuoteSub> quotes = {};
  int quoteUnsubscribeCount = 0;
  final Set<String> pending = {};
  final Map<String, ChainSub> chains = {};
  bool ordersSub = false;
  bool alertsSub = false;
  int seq = 0;
  DateTime lastHeard;
  DateTime? frozenUntil;
  bool _closed = false;

  MarketEngine get engine => gateway.engine;
  DateTime wallNow() => gateway.clock.wallNow();

  void start() {
    send({
      'type': 'welcome',
      'sessionId': id,
      'serverTime': wallNow().millisecondsSinceEpoch,
      'flushMs': gateway.flushInterval.inMilliseconds,
      'keepAliveMs': gateway.keepAliveInterval.inMilliseconds,
      'idleTimeoutMs': gateway.idleTimeout.inMilliseconds,
      'clock': clockJson(gateway.clock, gateway.calendar),
    });
    channel.stream.listen(_onMessage, onDone: _drop, onError: (_) => _drop());
  }

  void markChanged(Set<String> ids) {
    for (final s in ids) {
      if (quotes.containsKey(s)) pending.add(s);
    }
  }

  /// Sends the pending quotes whose throttle has elapsed in one `ticks`.
  void flush() {
    flushChains();
    if (pending.isEmpty || _isFrozen) return;
    final now = wallNow();
    // Up to half a flush of slack, so timer jitter does not push a 250 ms
    // throttle to the next 500 ms flush.
    final halfFlush = gateway.flushInterval.inMilliseconds ~/ 2;
    final due = <String>[
      for (final s in pending)
        if (quotes[s] case final q?)
          if (!gateway.isIdFrozen(s) &&
              (q.lastSentAt == null ||
                  now.difference(q.lastSentAt!).inMilliseconds >=
                      q.throttleMs - min(halfFlush, q.throttleMs ~/ 2)))
            s,
    ];
    pending.removeAll(due);
    sendTicks(due, now);
  }

  /// `ka`: ids not confirmed in the last 250 ms. Sent only
  /// when the list is non-empty.
  void keepAlive() {
    if ((quotes.isEmpty && chains.isEmpty) || _isFrozen) return;
    final now = wallNow();
    final ids = <String>[
      for (final MapEntry(key: s, value: q) in quotes.entries)
        if (!gateway.isIdFrozen(s) &&
            (q.lastConfirmedAt == null ||
                now.difference(q.lastConfirmedAt!) > WsGateway.kaFreshFor))
          s,
    ];
    final chainIds = [
      for (final c in chains.values)
        if (!gateway.isIdFrozen(c.underlying)) c.id,
    ];
    final ex = frozenQuotes();
    if (ids.isEmpty && chainIds.isEmpty && ex.isEmpty) return;
    for (final s in ids) {
      quotes[s]!.lastConfirmedAt = now;
    }
    sendData('ka', {
      'quotes': ids,
      'chains': chainIds,
      if (ex.isNotEmpty) 'ex': ex,
    }, at: now);
  }

  /// A data frame: `seq` +1 and (unless [withAsOf] is false) `asOf`.
  void sendData(
    String type,
    Map<String, Object?> body, {
    bool withAsOf = true,
    DateTime? at,
  }) {
    if (_closed || _isFrozen) return;
    send({
      'type': type,
      'seq': ++seq,
      if (withAsOf) 'asOf': (at ?? wallNow()).millisecondsSinceEpoch,
      ...body,
    });
  }

  /// Drops the session first, so a half-open socket that never finishes the
  /// close handshake is not kept, buffered or closed again.
  Future<void> close(int code, String reason) async {
    if (_closed) return;
    _drop();
    await channel.sink
        .close(code, reason)
        .timeout(gateway.closeTimeout, onTimeout: () {})
        .catchError((Object _) {});
  }

  static Map<String, Object?>? _decodeMessage(Object? raw) {
    if (raw is! String) return null;
    try {
      return switch (jsonDecode(raw)) {
        final Map<String, Object?> map => map,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  void _onMessage(dynamic raw) {
    lastHeard = wallNow();
    if (_isFrozen) return; // a "dead" server hears nothing either
    final msg = _decodeMessage(raw);
    if (msg == null) {
      sendError('invalid_message', 'Send JSON text frames like {"op":"ping"}');
      return;
    }
    final requestId = msg['id'];
    switch (msg['op']) {
      case 'ping':
        send({
          'type': 'pong',
          'ts': msg['ts'],
          'serverTime': wallNow().millisecondsSinceEpoch,
        });
      case 'subscribe' || 'unsubscribe':
        onChannelOp(msg, requestId, subscribe: msg['op'] == 'subscribe');
      case 'resync':
        resync(requestId);
      default:
        sendError(
          'unknown_op',
          'op must be subscribe, unsubscribe, resync or ping',
          id: requestId,
        );
    }
  }

  void sendTicks(List<String> symbols, DateTime now, {bool snapshot = false}) {
    if (_closed || _isFrozen) return;
    if (symbols.isEmpty && !snapshot) return;
    final data = <Map<String, Object?>>[];
    for (final s in symbols) {
      final q = quotes[s];
      if (q == null || gateway.isIdFrozen(s)) continue;
      data.add(engine.quoteJson(engine[s]!, q.mode));
      q
        ..lastSentAt = now
        ..lastConfirmedAt = now;
    }
    final ex = frozenQuotes();
    sendData('ticks', {
      if (snapshot) 'kind': 'snapshot',
      'data': data,
      if (ex.isNotEmpty) 'ex': ex,
    }, at: now);
  }

  /// Subscribed quote ids that are frozen, with their last confirmed
  /// `asOf` (ms, 0 when never confirmed).
  Map<String, int> frozenQuotes() => {
    for (final MapEntry(key: s, value: q) in quotes.entries)
      if (gateway.isIdFrozen(s))
        s: q.lastConfirmedAt?.millisecondsSinceEpoch ?? 0,
  };

  void sendError(String code, String message, {Object? id}) =>
      send({'type': 'error', 'id': id, 'code': code, 'message': message});

  void send(Map<String, Object?> message) {
    if (_closed || _isFrozen) return;
    channel.sink.add(jsonEncode(message));
  }

  bool get _isFrozen => frozenUntil != null && wallNow().isBefore(frozenUntil!);

  void _drop() {
    if (_closed) return;
    _closed = true;
    gateway.detach(this);
  }
}
