import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';

/// Price alerts.
abstract interface class AlertsRepository {
  Future<Result<List<PriceAlert>>> list();

  Future<Result<PriceAlert>> create(
    String symbol,
    AlertCondition cond,
    double level,
  );

  Future<Result<PriceAlert>> delete(String alertId);

  Stream<List<PriceAlert>> watchAll();

  /// Deduped by alertId (live + resync = one banner).
  Stream<PriceAlert> get triggered;
}
