import 'package:stock_pulse/core/network/domain/subscriptions.dart';

/// Server path of the market socket.
const socketPath = '/ws';

/// Every client → server socket request. The request `id` is echoed in
/// the server's `ack` / `error`.
sealed class SocketOp {
  const SocketOp();

  Map<String, Object?> toJson();
}

final class SubscribeQuotes extends SocketOp {
  const SubscribeQuotes(this.id, this.ids, this.mode, {this.throttleMs = 250});
  final int id;
  final List<String> ids;
  final FeedMode mode;
  final int throttleMs;

  @override
  Map<String, Object?> toJson() => {
    'op': 'subscribe',
    'id': id,
    'symbols': ids,
    'mode': mode.name,
    'throttleMs': throttleMs,
  };
}

final class UnsubscribeQuotes extends SocketOp {
  const UnsubscribeQuotes(this.id, this.ids);
  final int id;
  final List<String> ids;

  @override
  Map<String, Object?> toJson() => {
    'op': 'unsubscribe',
    'id': id,
    'symbols': ids,
  };
}

enum AccountChannel { orders, alerts }

final class SubscribeChannel extends SocketOp {
  const SubscribeChannel(this.id, this.channel);
  final int id;
  final AccountChannel channel;

  @override
  Map<String, Object?> toJson() => {
    'op': 'subscribe',
    'id': id,
    'channel': channel.name,
  };
}

final class UnsubscribeChannel extends SocketOp {
  const UnsubscribeChannel(this.id, this.channel);
  final int id;
  final AccountChannel channel;

  @override
  Map<String, Object?> toJson() => {
    'op': 'unsubscribe',
    'id': id,
    'channel': channel.name,
  };
}

/// [deviceMs] comes back in the `pong` to measure the round trip.
final class Ping extends SocketOp {
  const Ping(this.deviceMs);
  final int deviceMs;

  @override
  Map<String, Object?> toJson() => {'op': 'ping', 'ts': deviceMs};
}

final class SubscribeChain extends SocketOp {
  const SubscribeChain(
    this.id,
    this.underlying,
    this.expiry,
    this.from,
    this.to,
  );
  final int id;
  final String underlying;
  final String expiry;
  final int from;
  final int to;
  @override
  Map<String, Object?> toJson() => {
    'op': 'subscribe',
    'id': id,
    'channel': 'chain',
    'underlying': underlying,
    'expiry': expiry,
    'fromStrike': from,
    'toStrike': to,
  };
}

final class UnsubscribeChain extends SocketOp {
  const UnsubscribeChain(this.id, this.underlying, this.expiry);
  final int id;
  final String underlying;
  final String expiry;
  @override
  Map<String, Object?> toJson() => {
    'op': 'unsubscribe',
    'id': id,
    'channel': 'chain',
    'underlying': underlying,
    'expiry': expiry,
  };
}

/// Asks the server for a snapshot of every subscription after a `seq` gap.
final class Resync extends SocketOp {
  const Resync(this.id);
  final int id;

  @override
  Map<String, Object?> toJson() => {'op': 'resync', 'id': id};
}
