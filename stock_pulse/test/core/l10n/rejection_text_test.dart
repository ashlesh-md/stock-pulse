import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/l10n/locales/en/app_strings_en.dart';
import 'package:stock_pulse/core/l10n/strings/order_strings.dart';

void main() {
  const strings = AppStringsEn();
  String reason(AppError error) =>
      rejectionText(strings.orders, strings.errors, error);

  test(
    'each server rejection code has its own text, never the server text',
    () {
      for (final (code, expected) in [
        ('price_band', strings.orders.rejectedPriceBand),
        ('price_out_of_band', strings.orders.rejectedPriceBand),
        ('insufficient_holdings', strings.orders.rejectedHoldings),
        ('market_closed', strings.orders.blockClosed),
        ('invalid_quantity', strings.orders.rejectedQuantity),
        ('invalid_price', strings.orders.rejectedPrice),
        ('unknown_symbol', strings.orders.rejectedSymbol),
        ('invalid_order', strings.orders.rejectedInvalid),
        ('invalid_json', strings.orders.rejectedInvalid),
      ]) {
        final text = reason(ServerError(400, code, 'raw server text'));
        expect(text, expected, reason: code);
        expect(text, isNot(contains('raw server text')));
      }
    },
  );

  test('an unknown code or another error reads as the generic error', () {
    expect(
      reason(const ServerError(409, 'new_code', 'raw')),
      strings.errors.server,
    );
    expect(reason(const NetworkError()), strings.errors.network);
    expect(reason(const ParseError()), strings.errors.parse);
  });
}
