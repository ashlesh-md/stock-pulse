import 'dart:async';

import 'package:market_server/src/broker.dart';
import 'package:market_server/src/market_engine.dart';
import 'package:market_server/src/models.dart';

class AccountBook {
  AccountBook(this._engine, {DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc()) {
    for (final stock in _engine.stocks) {
      _previous[stock.id] = stock.ltp;
    }
    _ticks = _engine.ticks.listen((_) => evaluateAlerts());
  }

  final MarketEngine _engine;
  final DateTime Function() _clock;
  late final StreamSubscription<Set<String>> _ticks;
  final _events = StreamController<(String, Map<String, Object?>)>.broadcast(
    sync: true,
  );
  final _payments = <String, Map<String, Object?>>{};
  final _alerts = <String, Map<String, Object?>>{};
  final _fills = <String>{};
  final _previous = <String, double>{};
  double _available = 1000000;
  int _version = 0;
  int _nextAlert = 1;

  Stream<(String, Map<String, Object?>)> get events => _events.stream;
  Map<String, Object?> get funds => {
    'available': _available,
    'version': _version,
  };
  List<Map<String, Object?>> get alerts => List.unmodifiable(_alerts.values);

  void recordFill(Order order) {
    if (order.status != OrderStatus.complete || !_fills.add(order.id)) return;
    final sign = order.side == OrderSide.buy ? -1 : 1;
    _available += sign * order.quantity * order.averagePrice!;
    _version++;
    _events.add(('funds', funds));
  }

  Map<String, Object?> addFunds(double amount, String method, String key) {
    if (!amount.isFinite ||
        amount <= 0 ||
        amount > 10000000 ||
        !{'upi', 'netBanking'}.contains(method) ||
        key.isEmpty) {
      throw const OrderRejection(
        'invalid_payment',
        'Use a positive amount up to 10000000, a supported method and a payment key',
      );
    }
    final existing = _payments[key];
    if (existing != null) return existing;
    _available = ((_available + amount) * 100).round() / 100;
    _version++;
    final result = Map<String, Object?>.unmodifiable(funds);
    _payments[key] = result;
    _events.add(('funds', result));
    return result;
  }

  Map<String, Object?> createAlert(String symbol, String cond, double level) {
    if (_engine[symbol] == null) {
      throw const OrderRejection(
        'unknown_symbol',
        'Unknown instrument',
        status: 404,
      );
    }
    final stock = _engine[symbol]!;
    final ticks = level / stock.instrument.tickSize;
    if (!{'above', 'below'}.contains(cond) ||
        !level.isFinite ||
        level <= 0 ||
        (ticks - ticks.round()).abs() > 1e-6) {
      throw const OrderRejection(
        'invalid_level',
        'Use a positive level on the tick grid',
        status: 422,
      );
    }
    if (cond == 'above' ? stock.ltp >= level : stock.ltp <= level) {
      throw const OrderRejection(
        'condition_already_met',
        'The alert condition is already met',
        status: 422,
      );
    }
    if (_alerts.values.where((a) => a['status'] == 'active').length >= 50) {
      throw const OrderRejection('too_many_alerts', 'At most 50 active alerts');
    }
    final alert = <String, Object?>{
      'alertId': 'ALT${_nextAlert++}',
      'symbol': symbol,
      'cond': cond,
      'level': level,
      'status': 'active',
      'createdAt': _clock().toIso8601String(),
      'version': ++_version,
    };
    _alerts[alert['alertId']! as String] = alert;
    _events.add(('alert', Map.of(alert)));
    return Map.of(alert);
  }

  Map<String, Object?> cancelAlert(String id) {
    final alert = _alerts[id];
    if (alert == null) {
      throw const OrderRejection('not_found', 'No such alert', status: 404);
    }
    alert['status'] = 'cancelled';
    alert['version'] = ++_version;
    _events.add(('alert', Map.of(alert)));
    return Map.of(alert);
  }

  void evaluateAlerts() {
    for (final alert in _alerts.values) {
      if (alert['status'] != 'active') continue;
      final price = _engine[alert['symbol']! as String]!.ltp;
      final level = alert['level']! as double;
      final previous = _previous[alert['symbol']] ?? price;
      if (alert['cond'] == 'above'
          ? !(previous < level && price >= level)
          : !(previous > level && price <= level)) {
        continue;
      }
      alert.addAll({
        'status': 'triggered',
        'triggerLtp': price,
        'triggeredAt': _clock().toIso8601String(),
        'version': ++_version,
      });
      _events.add(('alert', Map.of(alert)));
    }
    for (final stock in _engine.stocks) {
      _previous[stock.id] = stock.ltp;
    }
  }

  void reset() {
    _available = 1000000;
    _version++;
    _payments.clear();
    _alerts.clear();
    _fills.clear();
    _events.add(('funds', funds));
  }

  void settlement(Map<String, Object?> value) =>
      _events.add(('settlement', value));

  Future<void> close() async {
    await _ticks.cancel();
    await _events.close();
  }
}
