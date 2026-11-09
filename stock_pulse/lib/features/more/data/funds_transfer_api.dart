import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/features/more/domain/funds_transfer.dart';
import 'package:stock_pulse/features/more/domain/payment_method.dart';
import 'package:stock_pulse/features/portfolio/data/portfolio_api.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';

class FundsTransferApi implements FundsTransfer {
  FundsTransferApi(this._api);

  final ApiClient _api;

  /// The server's names for [PaymentMethod].
  static String wireName(PaymentMethod method) => switch (method) {
    PaymentMethod.upi => 'upi',
    PaymentMethod.netBanking => 'netBanking',
  };

  @override
  Future<Result<Funds>> submit({
    required double amount,
    required PaymentMethod method,
    required String idempotencyKey,
  }) async {
    final result = await _api.call(
      addFundsEndpoint(
        amount: amount,
        method: wireName(method),
        idempotencyKey: idempotencyKey,
      ),
    );
    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final value) => parseJson(
        () => Funds.fromJson((value! as Map)['data'] as Map<String, Object?>),
      ),
    };
  }
}
