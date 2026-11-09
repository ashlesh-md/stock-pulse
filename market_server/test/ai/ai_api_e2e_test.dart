import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:market_server/src/ai/ai_api.dart';
import 'package:market_server/src/market_clock.dart';
import 'package:market_server/src/rest_api.dart' show demoToken, requireAuth;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

import 'fake_market_reads.dart';

/// A live answer as the client sees it: lines arrive as they are written.
class _Answer {
  _Answer(this.request, this.response) {
    response
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (l) => events.add(jsonDecode(l) as Map<String, Object?>),
          onDone: () => closed = true,
          onError: (Object _) => closed = true,
        );
  }

  final HttpClientRequest request;
  final HttpClientResponse response;
  final events = <Map<String, Object?>>[];
  bool closed = false;

  List<Object?> get kinds => [for (final e in events) e['e']];
}

void main() {
  late FakeMarketClock clock;
  late AnswerStream stream;
  late HttpServer server;
  late HttpClient client;

  Future<void> serve({required bool debug}) async {
    final reads = FakeMarketReads();
    clock = FakeMarketClock(wallStart: reads.wall);
    stream = AnswerStream(builder: AnswerBuilder(reads), clock: clock);
    final router = Router();
    mountAiApi(router, stream, debug: debug);
    final handler = const Pipeline()
        .addMiddleware(requireAuth())
        .addHandler(router.call);
    server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
    client = HttpClient();
  }

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  Uri askUri() => Uri.parse('http://127.0.0.1:${server.port}/api/v1/ai/ask');

  Future<HttpClientResponse> post(
    Object? body, {
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    final req = await client.postUrl(askUri());
    if (auth) req.headers.set('authorization', 'Bearer $demoToken');
    headers.forEach(req.headers.set);
    req.headers.contentType = ContentType.json;
    req.write(body is String ? body : jsonEncode(body));
    return req.close();
  }

  /// Advances the gated clock in small steps until [cond] holds.
  Future<void> until(
    bool Function() cond, {
    Duration step = const Duration(milliseconds: 10),
  }) async {
    for (var i = 0; i < 2000; i++) {
      if (cond()) return;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      clock.advance(step);
    }
    fail('condition not reached');
  }

  Future<_Answer> ask(
    String q, {
    Map<String, String> headers = const {},
  }) async {
    final req = await client.postUrl(askUri());
    req.headers.set('authorization', 'Bearer $demoToken');
    headers.forEach(req.headers.set);
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'question': q, 'requestId': 'r1'}));
    // Headers go out with the first line (after the held think delay), so
    // drive the clock while waiting for them.
    HttpClientResponse? res;
    unawaited(req.close().then((r) => res = r));
    await until(() => res != null);
    return _Answer(req, res!);
  }

  test('S4 start and card 1 reach the client before done exists', () async {
    await serve(debug: false);
    final a = await ask('What does the NIFTY chain say?');
    expect(a.response.statusCode, 200);
    expect(
      a.response.headers.value('content-type'),
      'application/x-ndjson; charset=utf-8',
    );
    expect(a.response.headers.value('cache-control'), 'no-store');

    await until(() => a.events.length >= 2);
    expect(a.kinds, ['start', 'card']);
    // The generator is parked on a held delay: done has not been produced.
    expect(stream.active, 1);
    expect(a.closed, isFalse);

    await until(() => a.closed, step: const Duration(milliseconds: 50));
    expect(a.kinds.last, 'done');
    expect(a.kinds.where((k) => k == 'card'), hasLength(3));
    expect(stream.active, 0);
  });

  test('S5 abort after card 1 → active 0, nothing more produced', () async {
    await serve(debug: false);
    final a = await ask('What does the NIFTY chain say?');
    await until(() => a.events.length >= 2);
    expect(stream.active, 1);
    client.close(force: true); // drops the socket, like an app abort
    // One more card gap: the generator resumes, hits yield, sees the cancel.
    await until(
      () => stream.active == 0,
      step: const Duration(milliseconds: 150),
    );
    expect(stream.active, 0);
    expect(a.kinds, isNot(contains('done')));
  });

  test('S6 X-Debug-Fault error_after_card=2 → start, 2 cards, error', () async {
    await serve(debug: true);
    final a = await ask(
      'What does the NIFTY chain say?',
      headers: {'x-debug-fault': 'error_after_card=2'},
    );
    await until(() => a.closed, step: const Duration(milliseconds: 50));
    expect(a.kinds, ['start', 'card', 'card', 'error']);
    expect(a.events.last['code'], 'debug_fault');
    expect(a.events.last['retryable'], true);
  });

  test('S6 the fault header is ignored without debug', () async {
    await serve(debug: false);
    final a = await ask(
      'What does the NIFTY chain say?',
      headers: {'x-debug-fault': 'error_after_card=2'},
    );
    await until(() => a.closed, step: const Duration(milliseconds: 50));
    expect(a.kinds.last, 'done');
    expect(a.kinds, isNot(contains('error')));
  });

  test('S7 bad body → JSON 400 invalid_question', () async {
    await serve(debug: false);
    for (final body in <Object?>[
      'not json',
      {'question': '', 'requestId': 'r1'},
      {'question': 'x' * 201, 'requestId': 'r1'},
      {'question': 'hi'},
      {'question': 'hi', 'requestId': 'r1', 'context': 'NIFTY'},
    ]) {
      final res = await post(body);
      expect(res.statusCode, 400, reason: '$body');
      expect(res.headers.contentType?.mimeType, 'application/json');
      final json = jsonDecode(await utf8.decodeStream(res)) as Map;
      expect((json['error'] as Map)['code'], 'invalid_question');
    }
  });

  test('S7 no token → 401', () async {
    await serve(debug: false);
    final res = await post({'question': 'hi', 'requestId': 'r1'}, auth: false);
    expect(res.statusCode, 401);
    await res.drain<void>();
  });

  test('S7 gibberish → fallback card with the starter chips', () async {
    await serve(debug: false);
    final a = await ask('asdf qwerty');
    await until(() => a.closed, step: const Duration(milliseconds: 50));
    expect(a.kinds, ['start', 'card', 'done']);
    expect(a.events.first['intent'], 'unknown');
    final card = a.events[1]['card']! as Map;
    expect(card['type'], 'fallback');
    expect((card['body']! as Map)['chips'], hasLength(6));
    expect(a.events.last['chips'], hasLength(6));
  });
}
