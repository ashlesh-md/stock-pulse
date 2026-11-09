import 'dart:async';

import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/features/alerts/data/alerts_api.dart';
import 'package:stock_pulse/features/alerts/domain/alerts_repository.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';

class LiveAlertsRepository implements AlertsRepository {
  LiveAlertsRepository(this._api, this._socket);
  final ApiClient _api;
  final MarketSocket _socket;

  @override
  Future<Result<List<PriceAlert>>> list() async {
    final result = await _api.call(alertsEndpoint);
    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final value) => parseJson(
        () => [
          for (final row in (value! as Map)['data'] as List)
            PriceAlert.fromJson(row as Map<String, Object?>),
        ],
      ),
    };
  }

  @override
  Future<Result<PriceAlert>> create(
    String symbol,
    AlertCondition cond,
    double level,
  ) async =>
      _one(await _api.call(createAlertEndpoint(symbol, cond.name, level)));

  @override
  Future<Result<PriceAlert>> delete(String alertId) async =>
      _one(await _api.call(deleteAlertEndpoint(alertId)));

  @override
  Stream<List<PriceAlert>> watchAll() => Stream.multi((controller) {
    var active = true;
    final latest = <String, PriceAlert>{};
    void merge(Iterable<PriceAlert> alerts) {
      if (!active) return;
      for (final alert in alerts) {
        final previous = latest[alert.alertId];
        if (previous == null || alert.version >= previous.version) {
          latest[alert.alertId] = alert;
        }
      }
      controller.addSync(List.unmodifiable(latest.values));
    }

    Future<void> reload() async {
      switch (await list()) {
        case Success(:final value):
          merge(value);
        case Failure(:final error):
          if (active) controller.addErrorSync(error);
      }
    }

    final account = _socket.subscribeAccount(orders: false);
    final frames = _socket.messages
        .where((m) => m['type'] == 'alert')
        .map((m) => PriceAlert.fromJson(m['data']! as Map<String, Object?>))
        .listen((alert) => merge([alert]), onError: controller.addErrorSync);
    final removeReloader = _socket.registerResyncReloader(reload);
    unawaited(reload());
    controller.onCancel = () async {
      active = false;
      account.cancel();
      removeReloader();
      await frames.cancel();
    };
  });

  @override
  Stream<PriceAlert> get triggered => Stream.multi((controller) {
    final seen = <String>{};
    var seeded = false;
    final sub = watchAll().listen((alerts) {
      for (final alert in alerts) {
        if (alert.status != AlertStatus.triggered || !seen.add(alert.alertId)) {
          continue;
        }
        if (seeded) controller.addSync(alert);
      }
      seeded = true;
    }, onError: controller.addErrorSync);
    controller.onCancel = sub.cancel;
  });

  Result<PriceAlert> _one(Result<Object?> result) => switch (result) {
    Failure(:final error) => Failure(error),
    Success(:final value) => parseJson(
      () =>
          PriceAlert.fromJson((value! as Map)['data'] as Map<String, Object?>),
    ),
  };
}
