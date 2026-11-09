import 'package:market_server/src/account_book.dart';
import 'package:market_server/src/broker.dart';
import 'package:market_server/src/http_helpers.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

void mountAccountApi(Router router, AccountBook account, Broker broker) {
  router.get(
    '/api/v1/funds',
    (Request _) => jsonResponse({'data': account.funds}),
  );
  router.get(
    '/api/v1/holdings',
    (Request _) => jsonResponse({
      'data': [for (final holding in broker.holdings) holding.toJson()],
    }),
  );
  router.post('/api/v1/funds', (Request request) async {
    final data = await readJsonObject(request);
    if (data == null || data['amount'] is! num || data['method'] is! String) {
      return errorResponse(
        400,
        'invalid_payment',
        'Need amount and payment method',
      );
    }
    return _command(
      () => account.addFunds(
        (data['amount']! as num).toDouble(),
        data['method']! as String,
        request.headers['idempotency-key'] ?? '',
      ),
    );
  });
  router.get(
    '/api/v1/alerts',
    (Request _) => jsonResponse({'data': account.alerts}),
  );
  router.post('/api/v1/alerts', (Request request) async {
    final data = await readJsonObject(request);
    if (data == null ||
        data['symbol'] is! String ||
        data['cond'] is! String ||
        data['level'] is! num) {
      return errorResponse(
        400,
        'invalid_alert',
        'Need symbol, condition and level',
      );
    }
    return _command(
      () => account.createAlert(
        data['symbol']! as String,
        data['cond']! as String,
        (data['level']! as num).toDouble(),
      ),
      status: 201,
    );
  });
  router.delete(
    '/api/v1/alerts/<id>',
    (Request _, String id) => _command(() => account.cancelAlert(id)),
  );
  router.get('/api/v1/orders/<id>', (Request _, String id) {
    final order = broker.orders.where((o) => o.id == id).firstOrNull;
    return order == null
        ? errorResponse(404, 'not_found', 'Unknown order')
        : jsonResponse({'data': order.toJson()});
  });
}

Response _command(Map<String, Object?> Function() action, {int status = 200}) {
  try {
    return jsonResponse({'data': action()}, status: status);
  } on OrderRejection catch (e) {
    return errorResponse(e.status, e.code, e.message);
  }
}
