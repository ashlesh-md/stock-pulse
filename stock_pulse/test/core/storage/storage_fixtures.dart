import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show ProductType;
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

final t0 = DateTime.utc(2026, 11, 6, 9, 30);

Quote cachedQuote(String id, double ltp) => Quote(
  symbol: id,
  ltp: ltp,
  change: 12.3,
  changePercent: 0.87,
  prevClose: ltp - 12.3,
  lastTradeTime: t0,
  asOf: t0,
  fromCache: true,
);

AppSnapshot snapshotWith({
  DateTime? savedAt,
  int quotes = 3,
  int positions = 1,
  int holdings = 1,
}) {
  final ids = [for (var i = 0; i < quotes; i++) 'SYM$i'];
  return AppSnapshot(
    savedAt: savedAt ?? t0,
    watchlistIds: ids,
    quotes: [for (final id in ids) cachedQuote(id, 1000.5)],
    positions: [
      for (var i = 0; i < positions; i++)
        Position(
          symbol: 'SYM$i',
          product: ProductType.mis,
          quantity: 50,
          lots: 1,
          averagePrice: 1420.25,
          realizedPnl: 0,
        ),
    ],
    holdings: [
      for (var i = 0; i < holdings; i++)
        Holding(symbol: 'SYM$i', quantity: 10, averagePrice: 980.5),
    ],
  );
}
