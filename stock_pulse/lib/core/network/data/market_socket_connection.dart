part of 'market_socket.dart';

extension MarketSocketConnection on MarketSocket {
  void _onWelcome(Map<String, Object?> msg) {
    _attempt = 0;
    if (msg['serverTime'] case final int serverTime) {
      _serverClock?.onWelcome(serverTime, _clock.now());
    }
    _setStatus(SocketConnected(sessionId: '${msg['sessionId']}'));
    unawaited(_resyncCoordinator.onReconnect());
    _messageController.add(msg);
  }

  void _onPong(Map<String, Object?> msg) {
    final sent = msg['ts'];
    if ((sent, msg['serverTime']) case (final int ts, final int server)) {
      _serverClock?.onPong(ts, server, _clock.now());
    }
    final current = _status;
    if (sent is! int || current is! SocketConnected) return;
    final rtt = _clock.now().millisecondsSinceEpoch - sent;
    _setStatus(
      SocketConnected(
        sessionId: current.sessionId,
        latency: Duration(milliseconds: rtt),
      ),
    );
  }

  void _onClosed(int generation, String reason) {
    if (generation != _generation) return;
    _closeChannel(1000, reason);
    _quoteLingerTimer?.cancel();
    _quoteLingerTimer = null;
    _quoteLingerDeadlines.clear();
    _book.forgetServerState();
    if (_paused || _disposed) return;
    final delay = reason.startsWith('4002')
        ? Duration.zero
        : reconnectDelay(_attempt, max: config.maxBackoff, random: _random);
    _attempt++;
    _setStatus(
      SocketReconnecting(attempt: _attempt, delay: delay, reason: reason),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _open);
  }

  String _closeReason(WebSocketChannel channel) => channel.closeCode == null
      ? 'connection lost'
      : '${channel.closeCode} ${channel.closeReason ?? ''}'.trim();

  void _log(String text, {required bool outgoing}) {
    if (!_frameController.hasListener) return;
    _frameController.add(
      SocketFrame(outgoing: outgoing, text: text, at: _clock.now()),
    );
  }

  void _setStatus(SocketStatus status) {
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }
}
