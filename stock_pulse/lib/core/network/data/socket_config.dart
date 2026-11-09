class SocketConfig {
  const SocketConfig({
    this.pingInterval = const Duration(seconds: 5),
    this.staleAfter = const Duration(seconds: 12),
    this.delayedAfter = const Duration(seconds: 5),
    this.connectTimeout = const Duration(seconds: 8),
    this.maxBackoff = const Duration(seconds: 30),
  });

  /// How often the app sends `{"op":"ping"}`.
  final Duration pingInterval;

  /// No frame for this long = the connection is dead even if TCP never said
  /// so (a "half-open" connection: Wi-Fi dropped, server froze, NAT forgot
  /// us). Ticks arrive every 250 ms and pongs every [pingInterval], so
  /// silence this long is never normal.
  final Duration staleAfter;

  /// No data frame (ticks, keep-alive, account events) for this long while
  /// connected = the feed is shown as Delayed. Pongs do not count: a server
  /// that answers pings but streams nothing is still delayed.
  final Duration delayedAfter;
  final Duration connectTimeout;
  final Duration maxBackoff;
}
