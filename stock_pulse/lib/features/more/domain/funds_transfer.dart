import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/more/domain/payment_method.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';

/// Credits the demo account. The same idempotency key never credits twice.
abstract interface class FundsTransfer {
  Future<Result<Funds>> submit({
    required double amount,
    required PaymentMethod method,
    required String idempotencyKey,
  });
}
