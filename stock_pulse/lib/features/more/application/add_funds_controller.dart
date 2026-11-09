import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/more/application/add_funds_state.dart';
import 'package:stock_pulse/features/more/di/more_data_providers.dart';
import 'package:stock_pulse/features/more/domain/funds_limits.dart';
import 'package:stock_pulse/features/more/domain/payment_method.dart';

/// Validates and sends a simulated deposit. A retry of the same amount and
/// method reuses its idempotency key until one succeeds.
class AddFundsController extends Notifier<AddFundsState> {
  String? _key;
  (double, PaymentMethod)? _intent;

  @override
  AddFundsState build() => const AddFundsState();

  void selectMethod(PaymentMethod method) {
    if (state.submitting) return;
    state = AddFundsState(method: method);
  }

  /// [amount] is null when the field does not parse as a number.
  Future<void> submit(double? amount) async {
    if (state.submitting) return;
    final method = state.method;
    if (amount == null || !FundsLimits.isValidDeposit(amount)) {
      state = AddFundsState(method: method, invalidAmount: true);
      return;
    }
    if (_intent != (amount, method)) {
      _intent = (amount, method);
      _key = null;
    }
    final key = _key ??= _newKey();
    state = AddFundsState(method: method, submitting: true);
    final result = await ref
        .read(fundsTransferProvider)
        .submit(amount: amount, method: method, idempotencyKey: key);
    if (!ref.mounted) return;
    switch (result) {
      case Success(:final value):
        _key = null;
        _intent = null;
        state = AddFundsState(method: method, funds: value);
      case Failure():
        state = AddFundsState(method: method, failed: true);
    }
  }

  static String _newKey() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}
