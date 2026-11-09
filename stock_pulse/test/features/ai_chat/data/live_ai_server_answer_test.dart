import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/api_client_lines.dart';
import 'package:stock_pulse/features/ai_chat/data/live_ai_repository.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_event.dart';

/// Lines recorded from the current market_server for one quote question.
const _recorded = [
  r'''{"e":"start","answerId":"a11","intent":"quote","serverTime":1794116139492}''',
  r'''{"e":"card","card":{"id":"a11.c1","type":"quote","v":1,"title":"RELIANCE","asOf":1794116139492,"instruments":["RELIANCE"],"fallbackText":"RELIANCE 1,386.75 (−0.04%)","actions":[{"kind":"open_stock","label":"Open stock","args":{"instrumentId":"RELIANCE"}},{"kind":"set_alert","label":"Set alert","args":{"instrumentId":"RELIANCE"}}],"body":{"id":"RELIANCE","symbol":"RELIANCE","name":"Reliance Industries","ltp":1386.75,"change":-0.55,"changePct":-0.04,"prevClose":1387.3,"phase":"open"}}}''',
  r'''{"e":"card","card":{"id":"a11.c2","type":"chart","v":1,"title":"RELIANCE today · 5m","asOf":1794116139492,"instruments":["RELIANCE"],"fallbackText":"RELIANCE 5-minute chart for today","actions":[{"kind":"open_chart","label":"Open chart","args":{"instrumentId":"RELIANCE"}}],"body":{"id":"RELIANCE","interval":"5m","prevClose":1387.3,"points":[[1794177300000,1385.95],[1794177600000,1388.3],[1794177900000,1389.0]]}}}''',
  r'''{"e":"done","cards":2,"topic":{"underlying":"RELIANCE"},"chips":["RELIANCE chain","Compare RELIANCE and HDFCBANK"]}''',
];

void main() {
  test('a real server answer over ApiClient.postLines parses to start, cards '
      'and done, and the request carries a requestId', () async {
    Map<String, Object?>? sent;
    final api = ApiClient(
      const AppConfig(host: 'localhost'),
      client: MockClient.streaming((request, body) async {
        sent = jsonDecode(await body.bytesToString()) as Map<String, Object?>;
        return http.StreamedResponse(
          Stream.value(utf8.encode('${_recorded.join('\n')}\n')),
          200,
          headers: {'content-type': 'application/x-ndjson; charset=utf-8'},
        );
      }),
    );
    addTearDown(api.close);
    final repository = LiveAiRepository(postLines: api.postLines);

    final events = await repository.ask('How is RELIANCE doing?').toList();

    expect(sent?['requestId'], isA<String>());
    expect((sent!['requestId']! as String).length, inInclusiveRange(1, 64));
    expect(events.first, isA<AnswerStarted>());
    expect(events.whereType<CardAdded>(), hasLength(2));
    expect(events.last, isA<AnswerDone>());
    expect(events.whereType<AnswerFailed>(), isEmpty);
  });
}
