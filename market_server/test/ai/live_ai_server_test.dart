import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';

void main() {
  test(
    'real MarketServer AI streams and reports active answer lifecycle',
    () async {
      final calendar = MarketCalendar.nse();
      final marketDay = calendar.nextTradingDay(const IstDate(2026, 11, 8));
      final clock = FakeMarketClock(
        wallStart: DateTime.utc(2026, 11, 8, 5),
        marketStart: Ist.at(marketDay, 10, 0),
      );
      final server = MarketServer(
        clock: clock,
        calendar: calendar,
        random: Random(4),
        debug: true,
        flushInterval: const Duration(hours: 1),
        keepAliveInterval: const Duration(hours: 1),
      );
      final httpServer = await io.serve(
        server.handler,
        InternetAddress.loopbackIPv4,
        0,
      );
      final client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await httpServer.close(force: true);
        await server.close();
      });

      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${httpServer.port}/api/v1/ai/ask'),
      );
      request.headers
        ..set('authorization', 'Bearer $demoToken')
        ..contentType = ContentType.json;
      request.write(
        jsonEncode({
          'question': 'What does the NIFTY chain say?',
          'requestId': 'live-server-test',
        }),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'application/x-ndjson');

      final active = await _untilActive(server, expected: 1);
      expect(active, 1);
      final events = await response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) => jsonDecode(line) as Map<String, Object?>)
          .toList();
      expect(events.first['e'], 'start');
      expect(events.last['e'], 'done');
      expect(await _activeAnswers(server), 0);
    },
  );
}

Future<int> _untilActive(MarketServer server, {required int expected}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    final active = await _activeAnswers(server);
    if (active == expected) return active;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return _activeAnswers(server);
}

Future<int> _activeAnswers(MarketServer server) async {
  final response = await server.handler(
    Request('GET', Uri.parse('http://localhost/debug/subscriptions')),
  );
  final json = jsonDecode(await response.readAsString()) as Map;
  return (json['activeAiAnswers']! as num).toInt();
}
