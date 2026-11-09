import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/domain/socket_messages.dart';

void main() {
  test('every §4.2 frame type parses', () {
    final frames = <Map<String, Object?>>[
      {
        'type': 'welcome',
        'sessionId': 'S4',
        'serverTime': 1762412400000,
        'flushMs': 250,
        'keepAliveMs': 1000,
        'clock': {'phase': 'open', 'marketOffsetMs': 0, 'mode': 'demo'},
      },
      {
        'type': 'ticks',
        'seq': 100,
        'asOf': 1762412400250,
        'data': [
          {'s': 'RELIANCE', 'ltp': 1412.35},
        ],
        'ex': {'TCS': 1762412391000},
      },
      {
        'type': 'chain',
        'seq': 101,
        'kind': 'snapshot',
        'chainId': 'NIFTY:2026-11-10',
        'asOf': 1762412400250,
        'spot': 24612.35,
        'atm': 24600,
        'status': 'open',
        'rows': [
          {'k': 24600},
        ],
      },
      {
        'type': 'ka',
        'seq': 103,
        'asOf': 1762412401000,
        'quotes': ['TCS'],
        'chains': <String>[],
      },
      {'type': 'clock', 'seq': 104, 'phase': 'closed', 'marketOffsetMs': 0},
      for (final t in ['order', 'position', 'funds', 'settlement', 'alert'])
        {
          'type': t,
          'seq': 105,
          'data': {'id': 'x'},
        },
      {'type': 'ack', 'id': 1, 'op': 'subscribe'},
      {'type': 'error', 'id': 3, 'code': 'too_many_chains', 'message': 'm'},
      {'type': 'pong', 'ts': 1, 'serverTime': 2},
    ];
    final parsed = [for (final f in frames) SocketMessage.fromJson(f)];

    expect(parsed.map((m) => m.runtimeType.toString()), [
      'WelcomeMessage',
      'TicksMessage',
      'ChainMessage',
      'KeepAliveMessage',
      'ClockMessage',
      'OrderMessage',
      'PositionMessage',
      'FundsMessage',
      'SettlementMessage',
      'AlertMessage',
      'AckMessage',
      'ErrorMessage',
      'PongMessage',
    ]);
    final ticks = parsed[1] as TicksMessage;
    expect(ticks.seq, 100);
    expect(ticks.ex['TCS']!.millisecondsSinceEpoch, 1762412391000);
    final chain = parsed[2] as ChainMessage;
    expect(chain.kind, ChainFrameKind.snapshot);
    expect(chain.status, ChainStatus.open);
    expect((parsed[3] as KeepAliveMessage).quotes, ['TCS']);
    expect(parsed.last.seq, isNull);
    expect((parsed.last as PongMessage).serverTime, 2);
  });

  test(
    'unknown type → UnknownMessage; malformed known frame → FormatException',
    () {
      expect(
        SocketMessage.fromJson({'type': 'mystery'}),
        isA<UnknownMessage>(),
      );
      expect(
        () => SocketMessage.fromJson({'type': 'ticks', 'seq': 'x'}),
        throwsFormatException,
      );
    },
  );
}
