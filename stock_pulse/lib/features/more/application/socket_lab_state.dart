import 'package:flutter/foundation.dart';

import 'package:stock_pulse/core/network/domain/socket_status.dart';

@immutable
class SocketLabState {
  const SocketLabState({
    this.frames = const [],
    this.paused = false,
    this.received = 0,
    this.sent = 0,
    this.bytesIn = 0,
  });

  static const maxFrames = 500;

  /// Newest first, capped at [maxFrames] so memory stays flat.
  final List<SocketFrame> frames;

  /// Freezes the log so it can be read; frames are still counted.
  final bool paused;
  final int received;
  final int sent;
  final int bytesIn;

  SocketLabState copyWith({
    List<SocketFrame>? frames,
    bool? paused,
    int? received,
    int? sent,
    int? bytesIn,
  }) => SocketLabState(
    frames: frames ?? this.frames,
    paused: paused ?? this.paused,
    received: received ?? this.received,
    sent: sent ?? this.sent,
    bytesIn: bytesIn ?? this.bytesIn,
  );

  @override
  bool operator ==(Object other) =>
      other is SocketLabState &&
      listEquals(other.frames, frames) &&
      other.paused == paused &&
      other.received == received &&
      other.sent == sent &&
      other.bytesIn == bytesIn;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(frames), paused, received, sent, bytesIn);
}
