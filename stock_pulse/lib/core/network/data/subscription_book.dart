import 'dart:math';

import 'package:stock_pulse/core/network/domain/socket_ops.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';

/// Who holds what on the shared socket, and what the server has for the
/// current connection.
///
/// Holders are reference counted: the watchlist and the stock page can both
/// hold TCS. The server is asked for the biggest mode anyone needs and told
/// to unsubscribe only when the last holder leaves. [pendingOps] returns
/// only the difference, so a connection never gets a duplicate request.
class SubscriptionBook {
  final List<SocketSubscription> _quotes = [];
  final List<AccountSubscription> _accounts = [];
  final Map<String, (FeedMode, int)> _serverQuotes = {};
  final Map<String, (FeedMode, int)> _lingeringQuotes = {};
  final Set<AccountChannel> _serverChannels = {};
  final _chains = <ChainSubscription>[];
  final _serverChains = <String, (String, String, int, int)>{};
  int _requestId = 0;

  int nextRequestId() => ++_requestId;

  /// The server streams ticks and keep-alives only for quotes and chains;
  /// account channels can stay quiet for hours.
  bool get expectsData => _serverQuotes.isNotEmpty || _serverChains.isNotEmpty;

  void addChain(ChainSubscription holder) => _chains.add(holder);
  void removeChain(ChainSubscription holder) => _chains.remove(holder);

  void addQuotes(SocketSubscription holder) {
    for (final id in holder.symbols) {
      _lingeringQuotes.remove(id);
    }
    _quotes.add(holder);
  }

  Set<String> removeQuotes(
    SocketSubscription holder, {
    required bool lingerLastHolder,
  }) {
    _quotes.remove(holder);
    final lingering = <String>{};
    for (final id in holder.symbols) {
      final active = _effectiveQuote(id);
      if (active != null) {
        _lingeringQuotes.remove(id);
      } else {
        final quote = lingerLastHolder ? _serverQuotes[id] : null;
        if (quote == null) {
          _lingeringQuotes.remove(id);
        } else {
          _lingeringQuotes[id] = quote;
          lingering.add(id);
        }
      }
    }
    return lingering;
  }

  void expireQuoteLinger(String id) => _lingeringQuotes.remove(id);

  void addAccount(AccountSubscription holder) => _accounts.add(holder);

  void removeAccount(AccountSubscription holder) => _accounts.remove(holder);

  /// The server forgets a connection's subscriptions when it closes, so
  /// the next connection replays every holder.
  void forgetServerState() {
    _serverQuotes.clear();
    _lingeringQuotes.clear();
    _serverChannels.clear();
    _serverChains.clear();
  }

  /// Requests that bring the server in line with the holders. The book
  /// assumes every returned request is sent.
  List<SocketOp> pendingOps() => [
    ..._quoteOps(),
    ..._channelOps(),
    ..._chainOps(),
  ];

  List<SocketOp> _chainOps() {
    final wanted = <String, (String, String, int, int)>{};
    for (final holder in _chains) {
      final request = holder.request;
      final previous = wanted[request.chainId];
      wanted[request.chainId] = (
        request.underlying,
        request.expiry,
        previous == null
            ? holder.fromStrike
            : min(previous.$3, holder.fromStrike),
        previous == null ? holder.toStrike : max(previous.$4, holder.toStrike),
      );
    }
    final ops = <SocketOp>[];
    for (final entry in _serverChains.entries) {
      if (!wanted.containsKey(entry.key)) {
        ops.add(UnsubscribeChain(++_requestId, entry.value.$1, entry.value.$2));
      }
    }
    for (final entry in wanted.entries) {
      if (_serverChains[entry.key] == entry.value) continue;
      final value = entry.value;
      ops.add(
        SubscribeChain(++_requestId, value.$1, value.$2, value.$3, value.$4),
      );
    }
    _serverChains
      ..clear()
      ..addAll(wanted);
    return ops;
  }

  List<SocketOp> _quoteOps() {
    final wanted = _wantedQuotes();
    final removed = [
      for (final id in _serverQuotes.keys)
        if (!wanted.containsKey(id)) id,
    ];
    final added = <(FeedMode, int), List<String>>{};
    wanted.forEach((id, request) {
      if (_serverQuotes[id] != request) (added[request] ??= []).add(id);
    });
    removed.forEach(_serverQuotes.remove);
    added.forEach((request, ids) {
      for (final id in ids) {
        _serverQuotes[id] = request;
      }
    });
    return [
      if (removed.isNotEmpty) UnsubscribeQuotes(++_requestId, removed),
      for (final MapEntry(key: request, value: ids) in added.entries)
        SubscribeQuotes(++_requestId, ids, request.$1, throttleMs: request.$2),
    ];
  }

  Map<String, (FeedMode, int)> _wantedQuotes() {
    final wanted = <String, (FeedMode, int)>{};
    for (final holder in _quotes) {
      for (final id in holder.symbols) {
        final current = wanted[id];
        wanted[id] = current == null
            ? (holder.mode, holder.throttleMs)
            : (
                holder.mode.index > current.$1.index ? holder.mode : current.$1,
                holder.throttleMs < current.$2 ? holder.throttleMs : current.$2,
              );
      }
    }
    for (final entry in _lingeringQuotes.entries) {
      wanted.putIfAbsent(entry.key, () => entry.value);
    }
    return wanted;
  }

  (FeedMode, int)? _effectiveQuote(String id) {
    (FeedMode, int)? effective;
    for (final holder in _quotes) {
      if (!holder.symbols.contains(id)) continue;
      final current = effective;
      effective = current == null
          ? (holder.mode, holder.throttleMs)
          : (
              holder.mode.index > current.$1.index ? holder.mode : current.$1,
              holder.throttleMs < current.$2 ? holder.throttleMs : current.$2,
            );
    }
    return effective;
  }

  List<SocketOp> _channelOps() {
    final wanted = {
      if (_accounts.any((h) => h.orders)) AccountChannel.orders,
      if (_accounts.any((h) => h.alerts)) AccountChannel.alerts,
    };
    final ops = [
      for (final channel in _serverChannels.difference(wanted))
        UnsubscribeChannel(++_requestId, channel),
      for (final channel in wanted.difference(_serverChannels))
        SubscribeChannel(++_requestId, channel),
    ];
    _serverChannels
      ..clear()
      ..addAll(wanted);
    return ops;
  }
}
