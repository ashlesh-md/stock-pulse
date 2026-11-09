part of 'market_socket.dart';

extension MarketSocketQuoteSubscriptions on MarketSocket {
  SocketSubscription subscribe(
    Iterable<String> ids,
    FeedMode mode, {
    int throttleMs = 250,
  }) {
    final holder = SocketSubscription(
      ids,
      mode,
      throttleMs: throttleMs,
      onCancel: _cancelQuoteSubscription,
    );
    _sync(() {
      for (final id in holder.symbols) {
        _quoteLingerDeadlines.remove(id);
      }
      _scheduleQuoteLinger();
      _book.addQuotes(holder);
    });
    return holder;
  }

  void _cancelQuoteSubscription(SocketSubscription holder) {
    _sync(() {
      final lingered = _book.removeQuotes(
        holder,
        lingerLastHolder: _channel != null,
      );
      if (lingered.isNotEmpty) {
        final deadline = _clock.now().add(const Duration(milliseconds: 300));
        for (final id in lingered) {
          _quoteLingerDeadlines[id] = deadline;
        }
        _scheduleQuoteLinger();
      }
    });
  }

  void _scheduleQuoteLinger() {
    _quoteLingerTimer?.cancel();
    if (_quoteLingerDeadlines.isEmpty) {
      _quoteLingerTimer = null;
      return;
    }
    final earliest = _quoteLingerDeadlines.values.reduce(
      (a, b) => a.isBefore(b) ? a : b,
    );
    final delay = earliest.difference(DateTime.now());
    _quoteLingerTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      final now = _clock.now();
      final expired = [
        for (final entry in _quoteLingerDeadlines.entries)
          if (!entry.value.isAfter(now)) entry.key,
      ];
      for (final id in expired) {
        _quoteLingerDeadlines.remove(id);
      }
      _quoteLingerTimer = null;
      _sync(() {
        for (final id in expired) {
          _book.expireQuoteLinger(id);
        }
      });
      _scheduleQuoteLinger();
    });
  }
}
