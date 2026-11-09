import 'package:market_server/src/broker.dart';
import 'package:market_server/src/http_helpers.dart';
import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/market_clock.dart';
import 'package:market_server/src/market_engine.dart';
import 'package:market_server/src/models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// The only token the demo accepts. A real broker issues a session token after
/// login (OAuth); the app sends it on every REST call and when opening the
/// WebSocket.
const demoToken = 'demo-token';

const _intervals = {
  '1m': Duration(minutes: 1),
  '5m': Duration(minutes: 5),
  '15m': Duration(minutes: 15),
  '1h': Duration(hours: 1),
  '1d': Duration(days: 1),
  '1w': Duration(days: 7),
};

/// REST endpoints: everything that is request → response. Snapshots, history
/// and commands live here; the live stream lives on the WebSocket.
Router buildRestApi(
  MarketEngine engine,
  Broker broker, {
  required MarketClock clock,
  required MarketCalendar calendar,
}) {
  final router = Router();

  // Static facts plus today's band. `?kind=equity,index` (default)
  // filters by kind.
  router.get('/api/v1/instruments', (Request req) {
    final kinds = (req.url.queryParameters['kind'] ?? 'equity,index').split(
      ',',
    );
    return jsonResponse({
      'data': [
        for (final s in engine.stocks)
          if (kinds.contains(s.instrument.kind.wire))
            s.instrument.toJson(prevClose: s.prevClose),
      ],
    });
  });

  router.get('/api/v1/instruments/<id>', (Request _, String id) {
    final s = engine[id];
    if (s == null) {
      return errorResponse(404, 'unknown_symbol', 'No instrument "$id"');
    }
    return jsonResponse(s.instrument.toJson(prevClose: s.prevClose));
  });

  // Snapshot of current quotes. The app calls this before the socket is up,
  // and again after a reconnect or a missed message, to get a clean baseline.
  router.get('/api/v1/quotes', (Request req) {
    final symbols =
        req.url.queryParameters['symbols']?.split(',') ??
        [for (final s in engine.stocks) s.instrument.symbol];
    final mode = req.url.queryParameters['mode'] == 'full'
        ? FeedMode.full
        : FeedMode.quote;
    final unknown = symbols.where((s) => engine[s] == null).toList();
    if (unknown.isNotEmpty) {
      return errorResponse(
        404,
        'unknown_symbol',
        'Unknown: ${unknown.join(', ')}',
      );
    }
    // `asOf` (server wall time) lets the app keep a newer socket value over
    // an older REST one.
    return jsonResponse({
      'asOf': clock.wallNow().millisecondsSinceEpoch,
      'data': [for (final s in symbols) engine.quoteJson(engine[s]!, mode)],
    });
  });

  router.get(
    '/api/v1/clock',
    (Request _) => jsonResponse(clockJson(clock, calendar)),
  );

  // Historical candles. Charts load these once, then update the newest
  // candle themselves from live ticks.
  router.get('/api/v1/instruments/<symbol>/candles', (
    Request req,
    String symbol,
  ) {
    if (engine[symbol] == null) {
      return errorResponse(404, 'unknown_symbol', 'No instrument "$symbol"');
    }
    final name = req.url.queryParameters['interval'] ?? '1m';
    final interval = _intervals[name];
    if (interval == null) {
      return errorResponse(
        400,
        'invalid_interval',
        'Use one of ${_intervals.keys.join(', ')}',
      );
    }
    // Like Kite's historical API: an interval plus an optional time window
    // (`from`/`to` as epoch milliseconds), newest `limit` candles at most.
    DateTime? time(String key) {
      final ms = int.tryParse(req.url.queryParameters[key] ?? '');
      return ms == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }

    final limit = int.tryParse(req.url.queryParameters['limit'] ?? '') ?? 500;
    final candles = engine.candles(
      symbol,
      interval,
      from: time('from'),
      to: time('to'),
      limit: limit.clamp(1, 2000),
    );
    return jsonResponse({
      'symbol': symbol,
      'interval': name,
      'data': [for (final c in candles) c.toJson()],
    });
  });

  router.get('/api/v1/orders', (Request request) {
    final key = request.url.queryParameters['key'];
    return jsonResponse({
      'data': key == null
          ? [for (final o in broker.orders) o.toJson()]
          : broker.byClientKey(key)?.toJson(),
    });
  });

  router.post('/api/v1/orders', (Request req) async {
    final body = await readJsonObject(req);
    if (body == null) {
      return errorResponse(400, 'invalid_json', 'Body must be a JSON object');
    }
    final side = OrderSide.values.asNameMap()[body['side']];
    final type = OrderType.values.asNameMap()[body['type']];
    if (side == null ||
        type == null ||
        body['symbol'] is! String ||
        (body['quantity'] is! int && body['lots'] is! int) ||
        !_optional<int>(body['quantity']) ||
        !_optional<int>(body['lots']) ||
        !_optional<num>(body['triggerPrice']) ||
        !_optional<num>(body['limitPrice'])) {
      return errorResponse(
        400,
        'invalid_order',
        'Need symbol, side (buy|sell), type (market|limit), quantity',
      );
    }
    try {
      final order = broker.place(
        symbol: body['symbol']! as String,
        side: side,
        type: type,
        quantity: body['quantity'] as int? ?? 1,
        product:
            ProductType.values.asNameMap()[body['product']] ?? ProductType.mis,
        lots: body['lots'] as int?,
        triggerPrice: (body['triggerPrice'] as num?)?.toDouble(),
        limitPrice: (body['limitPrice'] as num?)?.toDouble(),
        idempotencyKey: req.headers['idempotency-key'],
      );
      return jsonResponse({'data': order.toJson()}, status: 201);
    } on OrderRejection catch (e) {
      return errorResponse(e.status, e.code, e.message);
    }
  });

  router.delete('/api/v1/orders/<id>', (Request _, String id) {
    try {
      return jsonResponse({'data': broker.cancel(id).toJson()});
    } on OrderRejection catch (e) {
      return errorResponse(e.status, e.code, e.message);
    }
  });

  router.get(
    '/api/v1/positions',
    (Request _) => jsonResponse({
      'data': [for (final p in broker.positions) p.toJson()],
    }),
  );

  return router;
}

/// Rejects /api calls without `Authorization: Bearer demo-token`.
Middleware requireAuth() =>
    (inner) => (req) {
      if (!req.url.path.startsWith('api/')) return inner(req);
      if (req.headers['authorization'] != 'Bearer $demoToken') {
        return errorResponse(
          401,
          'unauthorized',
          'Send Authorization: Bearer $demoToken',
        );
      }
      return inner(req);
    };

/// Lets a Flutter web build call the server from another origin.
Middleware cors() =>
    (inner) => (req) async {
      const headers = {
        'access-control-allow-origin': '*',
        'access-control-allow-headers':
            'authorization, content-type, idempotency-key',
        'access-control-allow-methods': 'GET, POST, DELETE, OPTIONS',
      };
      if (req.method == 'OPTIONS') return Response.ok(null, headers: headers);
      final res = await inner(req);
      return res.change(headers: headers);
    };

/// Adds a fixed delay to every REST call, to see loading states.
Middleware latency(Duration delay) =>
    (inner) => (req) async {
      if (delay > Duration.zero && req.url.path.startsWith('api/')) {
        await Future<void>.delayed(delay);
      }
      return inner(req);
    };

/// True when [value] is absent or a [T].
bool _optional<T>(Object? value) => value == null || value is T;
