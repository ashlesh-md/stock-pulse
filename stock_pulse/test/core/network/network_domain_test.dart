import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/data/core_api.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/core/network/domain/endpoint.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';

void main() {
  const req = ChainRequest(
    underlying: 'NIFTY',
    expiry: '2026-11-10',
    fromStrike: 24000,
    toStrike: 25000,
  );

  group('ChainRequest', () {
    test('chainId joins underlying and expiry', () {
      expect(req.chainId, 'NIFTY:2026-11-10');
    });

    test('equal by all four fields; copyWith changes the range', () {
      final moved = req.copyWith(fromStrike: 24100);
      expect(moved.fromStrike, 24100);
      expect(moved.toStrike, 25000);
      expect(moved, isNot(req));
      expect(req.copyWith(), req);
      expect(req.copyWith().hashCode, req.hashCode);
    });
  });

  group('ChainSubscription', () {
    test('reports a new range once and ignores the same range', () {
      final ranges = <(int, int)>[];
      final sub = ChainSubscription(
        req,
        onRange: (_, from, to) => ranges.add((from, to)),
      );
      expect((sub.fromStrike, sub.toStrike), (24000, 25000));
      sub
        ..updateRange(24000, 25000)
        ..updateRange(24100, 24900);
      expect(ranges, [(24100, 24900)]);
      expect((sub.fromStrike, sub.toStrike), (24100, 24900));
    });

    test('cancel notifies once; a cancelled holder ignores ranges', () {
      var cancels = 0;
      final ranges = <(int, int)>[];
      final sub =
          ChainSubscription(
              req,
              onRange: (_, from, to) => ranges.add((from, to)),
              onCancel: (_) => cancels++,
            )
            ..cancel()
            ..cancel()
            ..updateRange(1, 2);
      expect(sub.isCancelled, isTrue);
      expect(cancels, 1);
      expect(ranges, isEmpty);
    });
  });

  group('Endpoint', () {
    test('delete has no query or body and prints method and path', () {
      const e = Endpoint.delete('/x/1');
      expect(e.method, HttpMethod.delete);
      expect(e.query, isEmpty);
      expect(e.body, isNull);
      expect('$e', 'DELETE /x/1');
    });

    test('debug endpoints send the market time in UTC, reset without one', () {
      final at = DateTime.utc(2026, 11, 10, 4, 30);
      expect(setClockEndpoint(at).body, {'time': '2026-11-10T04:30:00.000Z'});
      expect(setClockEndpoint(at).path, '/debug/clock');
      expect(resetEndpoint(marketTime: at).body, {
        'time': '2026-11-10T04:30:00.000Z',
      });
      expect(resetEndpoint().body, isEmpty);
      expect(healthEndpoint.method, HttpMethod.get);
    });
  });

  group('socket messages', () {
    test('ack and error expose id, op, code and message, no seq', () {
      final ack = SocketMessage.fromJson({
        'type': 'ack',
        'id': 3,
        'op': 'subscribe',
      }) as AckMessage;
      expect((ack.id, ack.op, ack.seq), (3, 'subscribe', null));
      final error = SocketMessage.fromJson({
        'type': 'error',
        'id': 4,
        'code': 'unknown_symbol',
        'message': 'm',
      }) as ErrorMessage;
      expect(
        (error.id, error.code, error.message, error.seq),
        (4, 'unknown_symbol', 'm', null),
      );
    });

    test('welcome and unknown frames', () {
      final welcome = SocketMessage.fromJson({
        'type': 'welcome',
        'sessionId': 'S1',
      });
      expect(welcome.seq, isNull);
      final unknown = SocketMessage.fromJson({'type': 'new', 'seq': 9});
      expect(unknown, isA<UnknownMessage>());
      expect(unknown.seq, 9);
    });
  });
}
