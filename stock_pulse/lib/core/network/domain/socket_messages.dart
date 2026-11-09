import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';

/// Every server → client frame of protocol v2. Data frames carry `seq`;
/// `ack`, `error` and `pong` do not.
sealed class SocketMessage {
  const SocketMessage();

  int? get seq;

  /// Never throws for an unknown `type` ([UnknownMessage]); throws
  /// [FormatException] when a known frame is malformed.
  factory SocketMessage.fromJson(Map<String, Object?> j) {
    try {
      return switch (j['type']) {
        'welcome' => WelcomeMessage._(j),
        'ticks' => TicksMessage._(j),
        'chain' => ChainMessage._(j),
        'ka' => KeepAliveMessage._(j),
        'clock' => ClockMessage._(j),
        'order' => OrderMessage(_seq(j), _data(j)),
        'position' => PositionMessage(_seq(j), _data(j)),
        'funds' => FundsMessage(_seq(j), _data(j)),
        'settlement' => SettlementMessage(_seq(j), _data(j)),
        'alert' => AlertMessage(_seq(j), _data(j)),
        'ack' => AckMessage(j),
        'error' => ErrorMessage(j),
        'pong' => PongMessage._(j),
        _ => UnknownMessage(j),
      };
    } on TypeError catch (e) {
      throw FormatException('bad ${j['type']} frame: $e');
    }
  }
}

final class WelcomeMessage extends SocketMessage {
  WelcomeMessage._(Map<String, Object?> j)
    : sessionId = '${j['sessionId']}',
      serverTime = j['serverTime'] as int? ?? 0,
      flushMs = j['flushMs'] as int? ?? 250,
      keepAliveMs = j['keepAliveMs'] as int? ?? 1000,
      clock = j['clock'] is Map<String, Object?>
          ? MarketClockState.fromJson(j['clock']! as Map<String, Object?>)
          : MarketClockState.fallback;

  final String sessionId;

  /// Wall ms; 0 from a server that does not send it.
  final int serverTime;
  final int flushMs;
  final int keepAliveMs;
  final MarketClockState clock;

  @override
  int? get seq => null;
}

final class TicksMessage extends SocketMessage {
  TicksMessage._(Map<String, Object?> j)
    : seq = _seq(j),
      asOf = _time(j['asOf']),
      snapshot = j['kind'] == 'snapshot',
      data = _maps(j['data']),
      ex = _ex(j['ex']);

  @override
  final int seq;
  final DateTime asOf;
  final bool snapshot;
  final List<Map<String, Object?>> data;

  /// Subscribed ids NOT confirmed by this frame, with their last asOf.
  final Map<String, DateTime> ex;
}

enum ChainFrameKind { snapshot, delta, status }

enum ChainStatus { open, expired }

final class ChainMessage extends SocketMessage {
  ChainMessage._(Map<String, Object?> j)
    : seq = _seq(j),
      chainId = j['chainId']! as String,
      kind = ChainFrameKind.values.byName(j['kind']! as String),
      asOf = _time(j['asOf']),
      spot = (j['spot'] as num?)?.toDouble(),
      atm = j['atm'] as int?,
      status = switch (j['status']) {
        final String s => ChainStatus.values.byName(s),
        _ => null,
      },
      partial = j['partial'] as bool? ?? false,
      rows = _maps(j['rows']),
      ex = _ex(j['ex']),
      nextExpiry = j['nextExpiry'] as String?;

  @override
  final int seq;
  final String chainId;
  final ChainFrameKind kind;
  final DateTime asOf;
  final double? spot;
  final int? atm;
  final ChainStatus? status;
  final bool partial;
  final List<Map<String, Object?>> rows;
  final Map<String, DateTime> ex;
  final String? nextExpiry;
}

/// `ka`: confirms the listed ids are unchanged as of [asOf].
final class KeepAliveMessage extends SocketMessage {
  KeepAliveMessage._(Map<String, Object?> j)
    : seq = _seq(j),
      asOf = _time(j['asOf']),
      quotes = _strings(j['quotes']),
      chains = _strings(j['chains']);

  @override
  final int seq;
  final DateTime asOf;
  final List<String> quotes;
  final List<String> chains;
}

final class ClockMessage extends SocketMessage {
  ClockMessage._(Map<String, Object?> j)
    : seq = _seq(j),
      clock = MarketClockState.fromJson(j);

  @override
  final int seq;
  final MarketClockState clock;
}

/// Account frames: the repositories parse [data] (version, clientKey).
sealed class AccountMessage extends SocketMessage {
  const AccountMessage(this.seq, this.data);

  @override
  final int seq;
  final Map<String, Object?> data;
}

final class OrderMessage extends AccountMessage {
  const OrderMessage(super.seq, super.data);
}

final class PositionMessage extends AccountMessage {
  const PositionMessage(super.seq, super.data);
}

final class FundsMessage extends AccountMessage {
  const FundsMessage(super.seq, super.data);
}

final class SettlementMessage extends AccountMessage {
  const SettlementMessage(super.seq, super.data);
}

final class AlertMessage extends AccountMessage {
  const AlertMessage(super.seq, super.data);
}

final class AckMessage extends SocketMessage {
  const AckMessage(this.raw);

  final Map<String, Object?> raw;

  int? get id => raw['id'] as int?;
  String? get op => raw['op'] as String?;

  @override
  int? get seq => null;
}

final class ErrorMessage extends SocketMessage {
  const ErrorMessage(this.raw);

  final Map<String, Object?> raw;

  int? get id => raw['id'] as int?;
  String get code => '${raw['code']}';
  String get message => '${raw['message']}';

  @override
  int? get seq => null;
}

final class PongMessage extends SocketMessage {
  PongMessage._(Map<String, Object?> j)
    : ts = j['ts'] as int?,
      serverTime = j['serverTime'] as int?;

  /// The ping's device ms, echoed.
  final int? ts;

  /// Null from a server that does not send it.
  final int? serverTime;

  @override
  int? get seq => null;
}

/// Ignored; logged in Socket Lab.
final class UnknownMessage extends SocketMessage {
  const UnknownMessage(this.raw);

  final Map<String, Object?> raw;

  @override
  int? get seq => raw['seq'] as int?;
}

int _seq(Map<String, Object?> j) => j['seq']! as int;

Map<String, Object?> _data(Map<String, Object?> j) =>
    j['data']! as Map<String, Object?>;

DateTime _time(Object? ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms! as int, isUtc: true);

List<Map<String, Object?>> _maps(Object? list) => [
  for (final m in list as List? ?? const []) m as Map<String, Object?>,
];

List<String> _strings(Object? list) => [
  for (final s in list as List? ?? const []) s as String,
];

Map<String, DateTime> _ex(Object? ex) => {
  for (final e in (ex as Map<String, Object?>? ?? const {}).entries)
    e.key: _time(e.value),
};
