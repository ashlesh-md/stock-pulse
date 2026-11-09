import 'dart:async';

import 'package:market_server/src/account_book.dart';
import 'package:market_server/src/broker.dart';
import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/market_clock.dart';
import 'package:market_server/src/market_engine.dart';
import 'package:market_server/src/option_book.dart';
import 'package:market_server/src/rest_api.dart' show demoToken;
import 'package:market_server/src/ws_session.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket close codes used by this server.
///
/// RFC 6455 defines 1000–1015 (1001 "going away", 1012 "service restart"),
/// but most client and server libraries (including package:web_socket) only
/// let application code SEND 1000 or 3000–4999. So the app-specific reasons
/// use the private 4000–4999 range, and the client decides what to do from
/// the code.
abstract final class CloseCodes {
  static const normal = 1000;
  static const idleTimeout = 4000; // client sent nothing for too long
  static const serverShutdown = 4001; // reconnect later
  static const reconnectNow = 4002; // e.g. deploy/rebalance: reconnect at once
}

/// Accepts WebSocket connections at `/ws?token=...` and streams market data
/// with protocol v2:
///
/// - client → `subscribe` / `unsubscribe` (channels `quotes` (default),
///   `orders`, `alerts`, `chain`), `resync`, `ping`
/// - server → `welcome`, `ack`, `ticks`, `ka`, `clock`, `order`, `pong`,
///   `error`
///
/// Every data frame carries `seq` (+1 per frame, per session) and `asOf`
/// (server **wall** time, ms); `welcome`, `ack`, `pong` and `error` carry no
/// `seq`. Timers are real; every callback reads [clock], so tests drive them
/// with [flushNow] / [keepAliveNow] and `FakeMarketClock.advance`.
class WsGateway {
  WsGateway(
    this._engine,
    this._broker, {
    required this.clock,
    required this.calendar,
    Stream<MarketPhase>? phaseChanges,
    AccountBook? account,
    this.options,
    this.flushInterval = const Duration(milliseconds: 250),
    this.keepAliveInterval = const Duration(seconds: 1),
    this.idleTimeout = const Duration(seconds: 30),
    this.maxQuotes = 100,
    this.closeTimeout = const Duration(seconds: 2),
  }) {
    _subs
      ..add(
        _engine.ticks.listen((ids) {
          for (final s in _sessions) {
            s.markChanged(ids);
          }
        }),
      )
      // Account events go only to sessions on the `orders` channel.
      ..add(
        _broker.updates.listen((order) {
          account?.recordFill(order);
          for (final s in _sessions.toList()) {
            if (s.ordersSub) {
              s.sendData('order', {'data': order.toJson()});
              for (final position in _broker.positions.where(
                (p) => p.symbol == order.symbol,
              )) {
                s.sendData('position', {'data': position.toJson()});
              }
            }
          }
        }),
      )
      ..add(clock.jumps.listen((_) => broadcastClock()));
    if (account != null) {
      _subs.add(
        account.events.listen((event) {
          for (final s in _sessions.toList()) {
            if (event.$1 == 'alert' ? s.alertsSub : s.ordersSub) {
              s.sendData(event.$1, {'data': event.$2});
            }
          }
        }),
      );
    }
    if (phaseChanges != null) {
      _subs.add(phaseChanges.listen((_) => broadcastClock()));
    }
    _flushTimer = Timer.periodic(flushInterval, (_) => flushNow());
    _keepAliveTimer = Timer.periodic(keepAliveInterval, (_) => keepAliveNow());
    _idleTimer = Timer.periodic(idleCheckEvery, (_) => idleCheckNow());
  }

  static const idleCheckEvery = Duration(seconds: 5);

  /// A quote confirmed more recently than this is not repeated in `ka`.
  static const kaFreshFor = Duration(milliseconds: 250);

  final MarketEngine _engine;
  final OptionBook? options;
  final Broker _broker;
  final MarketClock clock;
  final MarketCalendar calendar;

  /// How often pending ticks are sent. Ticks arriving in between are
  /// conflated: only the latest quote per id goes out.
  final Duration flushInterval;

  /// How often unchanged subscribed quotes are confirmed (`ka`).
  final Duration keepAliveInterval;
  final Duration idleTimeout;

  /// Quote ids per session.
  final int maxQuotes;

  /// How long a session close waits for the close handshake.
  final Duration closeTimeout;

  final Set<WsSession> _sessions = {};
  final Map<String, DateTime> _frozenIds = {};
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _flushTimer;
  Timer? _keepAliveTimer;
  Timer? _idleTimer;
  int _nextSessionId = 1;

  int get connectionCount => _sessions.length;

  MarketEngine get engine => _engine;

  void detach(WsSession session) => _sessions.remove(session);

  /// The shelf handler for `/ws`. The token is checked BEFORE the upgrade, so
  /// a bad token gets a plain HTTP 401 and the socket never opens.
  Handler get handler => (Request req) {
    if (req.url.queryParameters['token'] != demoToken) {
      return Response(401, body: 'Missing or invalid ?token=');
    }
    return webSocketHandler(
      (WebSocketChannel channel, String? _) => connect(channel),
      // Protocol-level ping frames: keep NATs/proxies from dropping an idle
      // TCP connection. The app ALSO sends its own JSON pings (see README).
      pingInterval: const Duration(seconds: 20),
    )(req);
  };

  /// Sends due pending quotes to every session (the 250 ms flush).
  void flushNow() {
    for (final s in _sessions.toList()) {
      s.flush();
    }
  }

  /// Confirms unchanged subscribed quotes with `ka` (the 1 s keep-alive).
  void keepAliveNow() {
    for (final s in _sessions.toList()) {
      s.keepAlive();
    }
  }

  /// Sends a `clock` frame to every session (jumps and phase changes).
  void broadcastClock() {
    final body = clockJson(clock, calendar);
    for (final s in _sessions.toList()) {
      s.sendData('clock', body);
    }
  }

  /// Debug: closes every socket with 4002 so clients must reconnect.
  Future<void> dropAll() async {
    for (final s in _sessions.toList()) {
      await s.close(CloseCodes.reconnectNow, 'debug drop');
    }
  }

  /// Debug: stops sending anything (even pongs) for [duration], like a
  /// half-open connection. The app should notice via its heartbeat.
  void freezeAll(Duration duration) {
    for (final s in _sessions) {
      s.frozenUntil = clock.wallNow().add(duration);
    }
  }

  /// Debug: stops confirming [id] for [duration] while the engine keeps
  /// trading it. Freezing an underlying also freezes its option contracts.
  void freezeId(String id, Duration duration) =>
      _frozenIds[id] = clock.wallNow().add(duration);

  bool isIdFrozen(String id) {
    final until = _frozenIds[id];
    if (until != null && clock.wallNow().isBefore(until)) return true;
    final underlying = _engine[id]?.instrument.underlying;
    return underlying != null && isIdFrozen(underlying);
  }

  /// `GET /debug/subscriptions`: what every session holds right now.
  Map<String, Object?> subscriptionsJson({int activeAiAnswers = 0}) {
    final sessions = [
      for (final s in _sessions)
        {
          'id': s.id,
          'quotes': s.quotes.length,
          'quoteIds': s.quotes.keys.toList()..sort(),
          'quoteUnsubscribeCount': s.quoteUnsubscribeCount,
          'chains': s.chains.length,
          'chainStrikes': s.chains.values.fold<int>(
            0,
            (sum, c) => sum + c.lastRows.length,
          ),
          'orders': s.ordersSub,
          'alerts': s.alertsSub,
        },
    ];
    return {
      'sessions': sessions,
      'totals': {
        'sessions': sessions.length,
        'quotes': _sessions.fold<int>(0, (sum, s) => sum + s.quotes.length),
        'chains': _sessions.fold<int>(0, (sum, s) => sum + s.chains.length),
      },
      'activeAiAnswers': activeAiAnswers,
    };
  }

  /// Debug: makes every session skip one sequence number, so clients see a gap.
  void skipSequence() {
    for (final s in _sessions) {
      s.seq++;
    }
  }

  Future<void> close() async {
    _flushTimer?.cancel();
    _keepAliveTimer?.cancel();
    _idleTimer?.cancel();
    for (final sub in _subs) {
      await sub.cancel();
    }
    await Future.wait([
      for (final s in _sessions.toList())
        s.close(CloseCodes.serverShutdown, 'server shutdown'),
    ]);
  }

  /// Closes sessions that sent nothing for [idleTimeout].
  void idleCheckNow() {
    final now = clock.wallNow();
    for (final s in _sessions.toList()) {
      if (now.difference(s.lastHeard) > idleTimeout) {
        unawaited(
          s.close(
            CloseCodes.idleTimeout,
            'no message for ${idleTimeout.inSeconds}s',
          ),
        );
      }
    }
  }

  /// Starts a session on an upgraded socket.
  void connect(WebSocketChannel channel) {
    final session = WsSession('S${_nextSessionId++}', channel, this);
    _sessions.add(session);
    session.start();
  }
}
