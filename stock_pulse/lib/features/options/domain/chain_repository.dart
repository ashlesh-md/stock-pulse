import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';

/// A live chain. Cancelling the [views] subscription ends it.
abstract interface class ChainFeed {
  Stream<ChainView> get views;

  /// Debounced 250 ms, then the socket range is the visible range ± 5 strikes.
  void setVisibleRange(int fromStrike, int toStrike);
}

/// Option chains.
abstract interface class ChainRepository {
  ChainFeed watchChain(ChainRequest req);

  Future<Result<List<Expiry>>> expiries(String underlying);

  Future<Result<ChainView>> getChain(String underlying, String expiry);
}
