import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/api_client_lines.dart';

void main() {
  test(
    'NDJSON handles UTF8 split across bytes, CRLF and blank lines',
    () async {
      final client = ApiClient(
        AppConfig.fromEnvironment(),
        client: MockClient.streaming((req, body) async {
          expect(req.headers['content-type'], 'application/json');
          return http.StreamedResponse(
            Stream.fromIterable(
              utf8.encode('{"text":"₹"}\r\n\n{"n":2}\n').map((b) => [b]),
            ),
            200,
          );
        }),
      );
      addTearDown(client.close);
      expect(await client.postLines('/ask', {}).toList(), [
        {'text': '₹'},
        {'n': 2},
      ]);
    },
  );
  test('bad JSON becomes ParseError', () async {
    final client = ApiClient(
      AppConfig.fromEnvironment(),
      client: MockClient.streaming(
        (req, body) async =>
            http.StreamedResponse(Stream.value(utf8.encode('broken\n')), 200),
      ),
    );
    addTearDown(client.close);
    await expectLater(
      client.postLines('/ask', {}).toList(),
      throwsA(isA<ParseError>()),
    );
  });
  test('HTTP failure becomes ServerError', () async {
    final client = ApiClient(
      AppConfig.fromEnvironment(),
      client: MockClient.streaming(
        (req, body) async => http.StreamedResponse(const Stream.empty(), 503),
      ),
    );
    addTearDown(client.close);
    await expectLater(
      client.postLines('/ask', {}).toList(),
      throwsA(isA<ServerError>()),
    );
  });

  for (final (name, error, expected) in [
    ('broken UTF-8 bytes', null, isA<ParseError>()),
    ('a dropped body stream', const HttpExceptionLike(), isA<NetworkError>()),
  ]) {
    test('$name while streaming ends the lines with an error', () async {
      final client = ApiClient(
        AppConfig.fromEnvironment(),
        client: MockClient.streaming(
          (req, body) async => http.StreamedResponse(
            error == null
                ? Stream.value([0xff, 0x0a])
                : Stream<List<int>>.error(error),
            200,
          ),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        client.postLines('/ask', {}).toList(),
        throwsA(expected),
      );
    });
  }

  testWidgets('C2 15 s without a line ends the answer with a NetworkError', (
    tester,
  ) async {
    final body = StreamController<List<int>>();
    addTearDown(body.close);
    final client = ApiClient(
      AppConfig.fromEnvironment(),
      client: MockClient.streaming(
        (req, _) async => http.StreamedResponse(body.stream, 200),
      ),
    );
    addTearDown(client.close);
    final lines = <Map<String, Object?>>[];
    Object? error;
    client
        .postLines('/ask', {})
        .listen(lines.add, onError: (Object e) => error = e);
    await tester.pump();
    body.add(utf8.encode('{"n":1}\n'));
    await tester.pump(const Duration(seconds: 14));
    expect(lines, [
      {'n': 1},
    ]);
    expect(error, isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(error, isA<NetworkError>());
  });
}

class HttpExceptionLike implements Exception {
  const HttpExceptionLike();
}
