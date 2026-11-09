import 'package:market_server/src/market_engine.dart';
import 'package:market_server/src/ws_chain.dart';
import 'package:market_server/src/ws_session.dart';

/// Client requests that change what a session receives.
extension WsSessionOps on WsSession {
  void onChannelOp(
    Map<String, Object?> msg,
    Object? requestId, {
    required bool subscribe,
  }) {
    // `channel` missing → quotes, so older clients keep working.
    switch (msg['channel'] ?? 'quotes') {
      case 'quotes':
        subscribe
            ? _subscribeQuotes(msg, requestId)
            : _unsubscribeQuotes(msg, requestId);
      case 'orders':
        ordersSub = subscribe;
        _ackChannel(requestId, subscribe, 'orders');
      case 'alerts':
        // TODO(dev-realtime): no server-side alerts engine sends frames yet.
        alertsSub = subscribe;
        _ackChannel(requestId, subscribe, 'alerts');
      case 'chain':
        changeChain(msg, requestId, subscribe: subscribe);
      default:
        sendError(
          'unknown_channel',
          'channel must be quotes, chain, orders or alerts',
          id: requestId,
        );
    }
  }

  void _subscribeQuotes(Map<String, Object?> msg, Object? requestId) {
    final mode = FeedMode.values.asNameMap()[msg['mode'] ?? 'quote'];
    if (mode == null) {
      sendError(
        'invalid_mode',
        'mode must be ltp, quote or full',
        id: requestId,
      );
      return;
    }
    final throttle = msg['throttleMs'] ?? 250;
    if (throttle is! int || throttle < 0) {
      sendError(
        'invalid_message',
        'throttleMs must be a non-negative integer',
        id: requestId,
      );
      return;
    }
    final symbols = _symbols(msg);
    final unknown = symbols.where((s) => engine[s] == null).toList();
    if (unknown.isNotEmpty) {
      sendError(
        'unknown_symbol',
        'Unknown: ${unknown.join(', ')}',
        id: requestId,
      );
      return;
    }
    final newCount = {...quotes.keys, ...symbols}.length;
    if (newCount > gateway.maxQuotes) {
      sendError(
        'too_many_subscriptions',
        'Max ${gateway.maxQuotes} symbols per connection',
        id: requestId,
      );
      return;
    }
    // Re-subscribing an id replaces its mode and throttle.
    for (final s in symbols) {
      final q = quotes[s];
      if (q == null) {
        quotes[s] = QuoteSub(mode, throttle);
      } else {
        q
          ..mode = mode
          ..throttleMs = throttle;
      }
    }
    send({
      'type': 'ack',
      'id': requestId,
      'op': 'subscribe',
      'channel': 'quotes',
      'symbols': symbols,
      'mode': mode.name,
      'throttleMs': throttle,
    });
    // Send the current values right away so the app does not wait for the
    // next trade to show something.
    pending.removeAll(symbols);
    sendTicks(symbols, wallNow());
  }

  void _unsubscribeQuotes(Map<String, Object?> msg, Object? requestId) {
    final symbols = _symbols(msg);
    quoteUnsubscribeCount += symbols.where(quotes.containsKey).length;
    symbols.forEach(quotes.remove);
    pending.removeAll(symbols);
    send({
      'type': 'ack',
      'id': requestId,
      'op': 'unsubscribe',
      'channel': 'quotes',
      'symbols': symbols,
    });
  }

  void _ackChannel(Object? requestId, bool subscribe, String channel) => send({
    'type': 'ack',
    'id': requestId,
    'op': subscribe ? 'subscribe' : 'unsubscribe',
    'channel': channel,
  });

  /// One `ticks` snapshot of every subscribed quote, one chain
  /// snapshot per chain sub, then the ack carrying the last seq.
  void resync(Object? requestId) {
    pending.clear();
    sendTicks(quotes.keys.toList(), wallNow(), snapshot: true);
    flushChains(snapshot: true);
    send({'type': 'ack', 'id': requestId, 'op': 'resync', 'seq': seq});
  }

  List<String> _symbols(Map<String, Object?> msg) => [
    for (final s in (msg['symbols'] as List? ?? const [])) '$s',
  ];
}
