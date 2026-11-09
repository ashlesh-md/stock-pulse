import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/more/application/add_funds_state.dart';
import 'package:stock_pulse/features/more/di/funds_providers.dart';
import 'package:stock_pulse/features/more/di/more_data_providers.dart';
import 'package:stock_pulse/features/more/domain/funds_limits.dart';
import 'package:stock_pulse/features/more/domain/payment_method.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';

import '../../helpers/fake_funds_transfer.dart';

void main() {
  late FakeFundsTransfer transfer;
  late ProviderContainer container;

  setUp(() {
    transfer = FakeFundsTransfer();
    container = ProviderContainer.test(
      overrides: [fundsTransferProvider.overrideWithValue(transfer)],
    );
    container.listen(addFundsControllerProvider, (_, _) {});
  });

  AddFundsState read() => container.read(addFundsControllerProvider);
  Future<void> submit(double? amount) =>
      container.read(addFundsControllerProvider.notifier).submit(amount);

  test('a failed transfer retries with the same key; success starts a new '
      'intent', () async {
    await submit(1000);
    await submit(1000);
    expect(transfer.calls[0].$3, transfer.calls[1].$3);
    expect(transfer.calls[0].$3, hasLength(32));
    expect(read().failed, isTrue);

    transfer.result = const Success(Funds(available: 1200));
    await submit(1000);
    expect(transfer.calls[2].$3, transfer.calls[0].$3);
    expect(read().funds?.available, 1200);
    expect(read().failed, isFalse);

    await submit(1000);
    expect(transfer.calls.last.$3, isNot(transfer.calls[0].$3));
  });

  test('a different amount or method gets a new key', () async {
    await submit(1000);
    await submit(2000);
    container
        .read(addFundsControllerProvider.notifier)
        .selectMethod(PaymentMethod.netBanking);
    await submit(2000);
    final keys = {for (final c in transfer.calls) c.$3};
    expect(keys, hasLength(3));
    expect(transfer.calls.last.$2, PaymentMethod.netBanking);
  });

  test('invalid amounts flag the field and send nothing', () async {
    for (final amount in <double?>[
      null,
      0,
      -1,
      double.nan,
      double.infinity,
      FundsLimits.maxDeposit + 1,
    ]) {
      await submit(amount);
      expect(read().invalidAmount, isTrue, reason: '$amount');
    }
    expect(transfer.calls, isEmpty);
    await submit(FundsLimits.maxDeposit);
    expect(read().invalidAmount, isFalse);
    expect(transfer.calls.single.$1, FundsLimits.maxDeposit);
  });

  test(
    'while submitting, another submit and a method change are ignored',
    () async {
      transfer.gate = Completer<void>();
      final first = submit(1000);
      expect(read().submitting, isTrue);
      await submit(1000);
      container
          .read(addFundsControllerProvider.notifier)
          .selectMethod(PaymentMethod.netBanking);
      expect(read().method, PaymentMethod.upi);
      transfer.gate!.complete();
      await first;
      expect(transfer.calls, hasLength(1));
      expect(read().submitting, isFalse);
    },
  );

  test('a result after dispose is dropped', () async {
    transfer.gate = Completer<void>();
    final pending = submit(1000);
    container.dispose();
    transfer.gate!.complete();
    await expectLater(pending, completes);
  });

  test('AddFundsState equality covers every field', () {
    const a = AddFundsState();
    expect(a, const AddFundsState());
    expect(a.hashCode, const AddFundsState().hashCode);
    for (final b in const [
      AddFundsState(method: PaymentMethod.netBanking),
      AddFundsState(submitting: true),
      AddFundsState(invalidAmount: true),
      AddFundsState(failed: true),
      AddFundsState(funds: Funds(available: 1)),
    ]) {
      expect(a == b, isFalse);
    }
  });
}
