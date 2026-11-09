import 'package:stock_pulse/core/network/domain/chain_request.dart';

/// How much data a subscription wants per symbol. Bigger modes cost more
/// bytes: ltp ≈ 5 fields, quote ≈ 13, full adds a 5-level order book.
enum FeedMode { ltp, quote, full }

/// A holder of quote ids on the shared socket. Call [cancel] when done; the
/// socket unsubscribes when the last holder of an id leaves.
class SocketSubscription {
  SocketSubscription(
    Iterable<String> ids,
    this.mode, {
    this.throttleMs = 250,
    this._onCancel,
  }) : symbols = List.unmodifiable(ids.toSet());

  /// Quote ids.
  final List<String> symbols;
  final FeedMode mode;
  final int throttleMs;
  final void Function(SocketSubscription sub)? _onCancel;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call(this);
  }
}

/// A holder of one option chain range.
class ChainSubscription {
  ChainSubscription(this.request, {this._onRange, this._onCancel})
    : fromStrike = request.fromStrike,
      toStrike = request.toStrike;

  final ChainRequest request;
  final void Function(ChainSubscription sub, int from, int to)? _onRange;
  final void Function(ChainSubscription sub)? _onCancel;
  int fromStrike;
  int toStrike;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void updateRange(int from, int to) {
    if (_cancelled || (from == fromStrike && to == toStrike)) return;
    fromStrike = from;
    toStrike = to;
    _onRange?.call(this, from, to);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call(this);
  }
}

/// A holder of the account channels (orders, alerts).
class AccountSubscription {
  AccountSubscription({
    required this.orders,
    required this.alerts,
    this._onCancel,
  });

  final bool orders;
  final bool alerts;
  final void Function(AccountSubscription sub)? _onCancel;
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _onCancel?.call(this);
  }
}
