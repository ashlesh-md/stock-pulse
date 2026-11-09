import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/domain/endpoint.dart';
import 'package:stock_pulse/features/more/domain/chaos.dart';
import 'package:stock_pulse/features/more/domain/chaos_trigger.dart';

Endpoint chaosEndpoint(Chaos chaos) => switch (chaos) {
  Chaos.drop => const Endpoint.post('/debug/drop-connections'),
  Chaos.freeze => const Endpoint.post('/debug/freeze'),
  Chaos.skipSeq => const Endpoint.post('/debug/skip-seq'),
};

class DebugChaosTrigger implements ChaosTrigger {
  DebugChaosTrigger(this._api);

  final ApiClient _api;

  @override
  Future<Result<void>> trigger(Chaos chaos) async =>
      switch (await _api.call(chaosEndpoint(chaos))) {
        Success() => const Success(null),
        Failure(:final error) => Failure(error),
      };
}
