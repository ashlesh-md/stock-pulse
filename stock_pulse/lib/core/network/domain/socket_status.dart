/// Connection state shown in the UI.
sealed class SocketStatus {
  const SocketStatus();
}

final class SocketConnecting extends SocketStatus {
  const SocketConnecting(this.attempt);
  final int attempt;
}

final class SocketConnected extends SocketStatus {
  const SocketConnected({required this.sessionId, this.latency});
  final String sessionId;

  /// Round trip of the last ping → pong.
  final Duration? latency;
}

final class SocketReconnecting extends SocketStatus {
  const SocketReconnecting({
    required this.attempt,
    required this.delay,
    required this.reason,
  });
  final int attempt;
  final Duration delay;
  final String reason;
}

/// The app is in the background, so the socket is closed on purpose.
final class SocketPaused extends SocketStatus {
  const SocketPaused();
}

/// One raw frame, for the Socket Lab screen.
class SocketFrame {
  const SocketFrame({
    required this.outgoing,
    required this.text,
    required this.at,
  });
  final bool outgoing;
  final String text;
  final DateTime at;
}
