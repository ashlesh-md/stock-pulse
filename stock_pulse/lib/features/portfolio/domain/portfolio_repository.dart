import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';
import 'package:stock_pulse/features/portfolio/domain/settlement.dart';

/// Orders, positions, holdings and funds. Commands go over REST because they
/// need an answer; what happens later (a limit order filling minutes after)
/// arrives on [orderUpdates].
abstract interface class PortfolioRepository {
  Stream<Order> get orderUpdates;

  Future<Result<List<Order>>> getOrders();

  Future<Result<List<Position>>> getPositions();

  /// Latest merged book; null until the first REST load or a cache seed.
  PortfolioBook? get current;

  Stream<List<Position>> watchPositions();

  Stream<List<Holding>> watchHoldings();

  Stream<Funds> watchFunds();

  Stream<Settlement> get settlements;

  Future<Result<List<Holding>>> getHoldings();

  Future<Result<Funds>> getFunds();

  /// Retries once after a `NetworkError`, with the same idempotency key, so
  /// the server returns the first order instead of creating a second.
  Future<Result<Order>> placeOrder({
    required String symbol,
    required OrderSide side,
    required OrderType type,
    required int quantity,
    double? limitPrice,
    String? idempotencyKey,
    ProductType product = ProductType.cnc,
    int? lots,
    double? triggerPrice,
  });

  Future<Result<Order>> cancelOrder(String id);
}

abstract interface class CacheSeedablePortfolio {
  void seedFromCache(PortfolioBook book);
}
