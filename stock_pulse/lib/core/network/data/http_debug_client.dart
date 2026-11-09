import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/core_api.dart';
import 'package:stock_pulse/core/network/domain/debug_client.dart';

/// `/debug/*` over REST.
class HttpDebugClient implements DebugClient {
  HttpDebugClient(this._api);

  final ApiClient _api;

  @override
  Future<Result<MarketClockState>> setClock(DateTime marketTime) async {
    final result = await _api.call(setClockEndpoint(marketTime));
    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final value) => _parseClock(value),
    };
  }

  @override
  Future<Result<void>> reset({DateTime? marketTime}) async {
    final result = await _api.call(resetEndpoint(marketTime: marketTime));
    return result.map((_) {});
  }

  Result<MarketClockState> _parseClock(Object? value) => parseJson(() {
    final json = value! as Map<String, Object?>;
    final clock = (json['data'] ?? json) as Map<String, Object?>;
    return MarketClockState.fromJson(clock);
  });
}
