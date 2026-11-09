import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/more/domain/payment_method.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';

@immutable
class AddFundsState {
  const AddFundsState({
    this.method = PaymentMethod.upi,
    this.submitting = false,
    this.invalidAmount = false,
    this.failed = false,
    this.funds,
  });

  final PaymentMethod method;
  final bool submitting;

  /// The last amount tried was empty, not a number or out of range.
  final bool invalidAmount;

  /// The server refused or did not answer; a retry reuses the same key.
  final bool failed;

  /// Balance after the last successful deposit.
  final Funds? funds;

  @override
  bool operator ==(Object other) =>
      other is AddFundsState &&
      other.method == method &&
      other.submitting == submitting &&
      other.invalidAmount == invalidAmount &&
      other.failed == failed &&
      other.funds == funds;

  @override
  int get hashCode =>
      Object.hash(method, submitting, invalidAmount, failed, funds);
}
