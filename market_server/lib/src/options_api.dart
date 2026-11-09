import 'package:market_server/src/broker.dart';
import 'package:market_server/src/http_helpers.dart';
import 'package:market_server/src/option_book.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

void mountOptionsApi(Router router, OptionBook options) {
  router.get(
    '/api/v1/options/<underlying>/expiries',
    (Request _, String underlying) =>
        _response(() => {'data': options.expiries(underlying)}),
  );
  router.get(
    '/api/v1/options/<underlying>/<expiry>',
    (Request _, String underlying, String expiry) =>
        _response(() => {'data': options.chain(underlying, expiry)}),
  );
}

Response _response(Map<String, Object?> Function() build) {
  try {
    return jsonResponse(build());
  } on OrderRejection catch (e) {
    return errorResponse(e.status, e.code, e.message);
  }
}
