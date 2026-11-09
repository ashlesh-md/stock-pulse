import 'dart:convert';

import 'package:market_server/src/account_book.dart';
import 'package:market_server/src/broker.dart';
import 'package:market_server/src/fault_injector.dart';
import 'package:market_server/src/http_helpers.dart';
import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/market_clock.dart';
import 'package:market_server/src/ws_gateway.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

void mountDebugApi(
  Router router,
  MarketClock clock,
  MarketCalendar calendar,
  Broker broker,
  AccountBook account, {
  required WsGateway gateway,
  required FaultInjector faults,
  required int Function() activeAiAnswers,
}) {
  router.post('/debug/clock', (Request request) async {
    final time = await _time(request);
    if (time == null) return errorResponse(400, 'invalid_time', 'invalid_time');
    if (time.isBefore(clock.marketNow())) {
      return errorResponse(
        409,
        'backward_jump_requires_reset',
        'backward_jump_requires_reset',
      );
    }
    clock.jumpTo(time);
    return jsonResponse(clockJson(clock, calendar));
  });
  router.post('/debug/reset', (Request request) async {
    final time = await _time(request);
    broker.reset();
    account.reset();
    if (time != null) clock.jumpTo(time);
    return jsonResponse(clockJson(clock, calendar));
  });
  router.post('/debug/faults', (Request request) async {
    final body = await _json(request);
    final plan = body == null ? null : FaultPlan.fromJson(body);
    if (plan == null) {
      return errorResponse(400, 'invalid_fault', 'invalid_fault');
    }
    faults.add(plan);
    return jsonResponse({'pending': faults.pending});
  });
  router.delete('/debug/faults', (Request _) {
    faults.clear();
    return jsonResponse({'pending': 0});
  });
  router.get(
    '/debug/subscriptions',
    (Request _) => jsonResponse(
      gateway.subscriptionsJson(activeAiAnswers: activeAiAnswers()),
    ),
  );
}

Future<Map<String, Object?>?> _json(Request request) async {
  try {
    return switch (jsonDecode(await request.readAsString())) {
      final Map<String, Object?> map => map,
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

Future<DateTime?> _time(Request request) async =>
    switch (await _json(request)) {
      {'time': final String time} => DateTime.tryParse(time)?.toUtc(),
      _ => null,
    };
