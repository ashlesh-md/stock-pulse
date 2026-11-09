/// Deposit rules, matching the server's.
abstract final class FundsLimits {
  /// Largest single deposit, in rupees.
  static const maxDeposit = 10000000.0;

  /// Amounts offered as one-tap chips, in rupees.
  static const quickAmounts = [1000.0, 5000.0, 10000.0, 50000.0];

  static bool isValidDeposit(double? amount) =>
      amount != null && amount.isFinite && amount > 0 && amount <= maxDeposit;
}
