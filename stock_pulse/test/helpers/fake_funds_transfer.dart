import 'dart:async';

import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/more/domain/funds_transfer.dart';
import 'package:stock_pulse/features/more/domain/payment_method.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';

/// Records each deposit; complete [gate] to let a pending one answer.
class FakeFundsTransfer implements FundsTransfer {
  final calls = <(double, PaymentMethod, String)>[];
  Result<Funds> result = const Failure(NetworkError());
  Completer<void>? gate;

  @override
  Future<Result<Funds>> submit({
    required double amount,
    required PaymentMethod method,
    required String idempotencyKey,
  }) async {
    calls.add((amount, method, idempotencyKey));
    await gate?.future;
    return result;
  }
}
