import 'dart:convert';

import 'package:shelf/shelf.dart';

const _jsonType = {'content-type': 'application/json; charset=utf-8'};

/// A JSON response with [status].
Response jsonResponse(Object value, {int status = 200}) =>
    Response(status, body: jsonEncode(value), headers: _jsonType);

/// The error envelope every endpoint uses: `{"error": {code, message}}`.
Response errorResponse(int status, String code, String message) =>
    jsonResponse({
      'error': {'code': code, 'message': message},
    }, status: status);

/// The request body as a JSON object, or null when it is not one.
Future<Map<String, Object?>?> readJsonObject(Request request) async {
  try {
    final decoded = jsonDecode(await request.readAsString());
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}
