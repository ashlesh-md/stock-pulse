import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

void main() {
  final full = {
    's': 'TCS',
    'ltp': 3000.0,
    'ch': 10.0,
    'chp': 0.33,
    't': 1000,
    'o': 2990.0,
    'h': 3010.0,
    'l': 2980.0,
    'pc': 2990.0,
    'v': 5000,
    'lq': 3,
    'bid': 2999.95,
    'ask': 3000.05,
    'depth': {
      'bids': [
        {'p': 2999.95, 'q': 10, 'n': 2},
      ],
      'asks': [
        {'p': 3000.05, 'q': 7, 'n': 1},
      ],
    },
  };

  test('parses a full-mode quote', () {
    final q = Quote.fromJson(full);
    expect(q.symbol, 'TCS');
    expect(q.spread, closeTo(0.10, 1e-9));
    expect(q.bids.single.quantity, 10);
    expect(
      q.lastTradeTime,
      DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
    );
  });

  test('an ltp-mode update keeps fields it does not carry', () {
    final q = Quote.fromJson(full).mergeJson({
      's': 'TCS',
      'ltp': 3001.0,
      'ch': 11.0,
      'chp': 0.37,
      't': 2000,
    });
    expect(q.ltp, 3001.0);
    expect(q.open, 2990.0);
    expect(q.volume, 5000);
    expect(q.asks.single.price, 3000.05);
  });

  test('== compares values, so select() can skip unchanged rows', () {
    expect(Quote.fromJson(full), Quote.fromJson(full));
    expect(
      Quote.fromJson(full) == Quote.fromJson(full).mergeJson({'ltp': 1.0}),
      isFalse,
    );
  });
}
