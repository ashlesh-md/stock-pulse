import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';
import 'package:stock_pulse/features/portfolio/domain/settlement.dart';

void main() {
  const position = Position(
    symbol: 'TCS',
    product: ProductType.mis,
    quantity: 10,
    lots: 1,
    averagePrice: 100,
    realizedPnl: 5,
    dayRealizedPnl: 2,
    version: 3,
  );

  group('Position', () {
    test('round-trips through JSON', () {
      expect(Position.fromJson(position.toJson()), position);
      expect(Position.fromJson(position.toJson()).hashCode, position.hashCode);
    });

    test('fromJson defaults product, day P&L and version', () {
      final p = Position.fromJson({
        'symbol': 'TCS',
        'quantity': 1,
        'averagePrice': 1,
        'realizedPnl': 0,
      });
      expect(
        (p.product, p.dayRealizedPnl, p.version),
        (ProductType.cnc, 0.0, 0),
      );
    });

    test('key joins symbol and product; P&L is marked at ltp', () {
      expect(position.key, 'TCS|mis');
      expect(position.unrealizedPnl(110), 100);
    });

    test('a different version is a different position', () {
      final newer = Position.fromJson({...position.toJson(), 'version': 4});
      expect(newer, isNot(position));
    });
  });

  test('Holding round-trips and compares by value', () {
    const h = Holding(symbol: 'TCS', quantity: 3, averagePrice: 90, version: 1);
    expect(Holding.fromJson(h.toJson()), h);
    expect(Holding.fromJson(h.toJson()).hashCode, h.hashCode);
    expect(Holding.fromJson({...h.toJson()}..remove('version')).version, 0);
  });

  test('Funds round-trips and compares by value', () {
    const f = Funds(available: 1000, version: 2);
    expect(Funds.fromJson(f.toJson()), f);
    expect(Funds.fromJson(f.toJson()).hashCode, f.hashCode);
    expect(Funds.fromJson({'available': 5}).version, 0);
    expect(f, isNot(const Funds(available: 999, version: 2)));
  });

  test('Settlement reads the wire JSON; equal by id, pnl and time', () {
    final json = {
      'settlementId': 'ST1',
      'symbol': 'NIFTY26N1024000CE',
      'product': 'nrml',
      'quantity': 65,
      'settlePrice': 12.5,
      'pnl': -300,
      'settledAt': '2026-11-10T10:00:00.000Z',
    };
    final s = Settlement.fromJson(json);
    expect(s.product, ProductType.nrml);
    expect((s.quantity, s.settlePrice, s.pnl), (65, 12.5, -300.0));
    expect(s, Settlement.fromJson(json));
    expect(s.hashCode, Settlement.fromJson(json).hashCode);
    expect(s, isNot(Settlement.fromJson({...json, 'pnl': 1})));
  });

  test('PortfolioBook compares its lists by value and is read-only', () {
    PortfolioBook book() => PortfolioBook(
      positions: const [position],
      holdings: const [Holding(symbol: 'X', quantity: 1, averagePrice: 1)],
      funds: const Funds(available: 1),
    );
    expect(book(), book());
    expect(book().hashCode, book().hashCode);
    expect(
      book(),
      isNot(PortfolioBook(positions: const [], holdings: const [])),
    );
    expect(() => book().positions.add(position), throwsUnsupportedError);
  });

  test('portfolio Order compares by id, status and update time', () {
    Map<String, Object?> json(String status) => {
      'id': 'ORD1',
      'symbol': 'TCS',
      'side': 'buy',
      'type': 'market',
      'quantity': 1,
      'status': status,
      'createdAt': '2026-11-10T04:00:00.000Z',
      'updatedAt': '2026-11-10T04:00:00.000Z',
    };
    final open = Order.fromJson(json('open'));
    expect(open, Order.fromJson(json('open')));
    expect(open.hashCode, Order.fromJson(json('open')).hashCode);
    expect(open, isNot(Order.fromJson(json('complete'))));
  });
}
