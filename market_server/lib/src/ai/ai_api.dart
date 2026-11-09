import 'dart:convert';

import 'package:market_server/src/ai/answer_stream.dart';
import 'package:market_server/src/ai/ask_request.dart';
import 'package:market_server/src/ai/ndjson.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

export 'answer_builder.dart' show AnswerBuilder;
export 'answer_stream.dart' show AnswerStream;

/// Mounts `POST /api/v1/ai/ask` on [r] (the auth middleware already applies).
/// A bad body is a JSON `400 invalid_question`; success streams NDJSON with
/// output buffering off so each line reaches the client as it is produced.
/// [debug] enables the `X-Debug-Fault: error_after_card=N` hook.
void mountAiApi(Router r, AnswerStream s, {required bool debug}) {
  r.post('/api/v1/ai/ask', (Request req) async {
    final AskRequest ask;
    try {
      ask = AskRequest.fromJson(jsonDecode(await req.readAsString()));
    } on FormatException catch (e) {
      return _invalid(e.source == null ? e.message : 'Body must be JSON');
    }
    final events = s.run(
      ask,
      debugErrorAfterCard: debug ? _faultAfter(req) : null,
    );
    return Response.ok(
      encodeNdjson(events),
      headers: {
        'content-type': 'application/x-ndjson; charset=utf-8',
        'cache-control': 'no-store',
      },
      context: {'shelf.io.buffer_output': false},
    );
  });
}

int? _faultAfter(Request req) {
  final m = RegExp(
    r'error_after_card=(\d+)',
  ).firstMatch(req.headers['x-debug-fault'] ?? '');
  return m == null ? null : int.parse(m.group(1)!);
}

Response _invalid(String message) => Response(
  400,
  body: jsonEncode({
    'error': {'code': 'invalid_question', 'message': message},
  }),
  headers: {'content-type': 'application/json; charset=utf-8'},
);
