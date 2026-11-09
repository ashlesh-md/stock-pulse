import 'dart:async';

import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/features/options/data/chain_folder.dart';
import 'package:stock_pulse/features/options/data/options_api.dart';
import 'package:stock_pulse/features/options/domain/chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/options/domain/expiry.dart';

class LiveChainRepository implements ChainRepository {
  LiveChainRepository(this._api, this._socket);
  final ApiClient _api;
  final MarketSocket _socket;

  @override
  ChainFeed watchChain(ChainRequest req) =>
      _LiveChainFeed(_socket, req, () => getChain(req.underlying, req.expiry));

  @override
  Future<Result<List<Expiry>>> expiries(String underlying) async =>
      switch (await _api.call(expiriesEndpoint(underlying))) {
        Failure(:final error) => Failure(error),
        Success(:final value) => parseJson(
          () => [
            for (final expiry in (value! as Map)['data'] as List)
              Expiry.fromJson(expiry as Map<String, Object?>),
          ],
        ),
      };

  @override
  Future<Result<ChainView>> getChain(String underlying, String expiry) async =>
      switch (await _api.call(chainEndpoint(underlying, expiry))) {
        Failure(:final error) => Failure(error),
        Success(:final value) => parseJson(
          () => foldChain((value! as Map)['data'] as Map<String, Object?>),
        ),
      };
}

class _LiveChainFeed implements ChainFeed {
  _LiveChainFeed(this._socket, this._request, this._fetch);
  final MarketSocket _socket;
  final ChainRequest _request;
  final Future<Result<ChainView>> Function() _fetch;
  void Function(int, int)? _range;

  @override
  late final Stream<ChainView> views = Stream.multi((controller) {
    var active = true;
    ChainView? current;
    Timer? debounce;
    final holder = _socket.subscribeChain(_request);
    _range = (from, to) {
      debounce?.cancel();
      debounce = Timer(
        const Duration(milliseconds: 250),
        () => holder.updateRange(from, to),
      );
    };
    final frames = _socket.messages.listen((m) {
      if (m['type'] == 'chain' && m['chainId'] == _request.chainId) {
        final parsed = parseJson(() => foldChain(m, current));
        if (parsed case Success(:final value)) {
          current = value;
          controller.addSync(value);
        }
      } else if (m['type'] == 'ka' &&
          (m['chains'] as List? ?? const []).contains(_request.chainId)) {
        final previous = current;
        if (previous != null) {
          current = previous.copyWith(
            asOf: DateTime.fromMillisecondsSinceEpoch(
              m['asOf']! as int,
              isUtc: true,
            ),
          );
          controller.addSync(current!);
        }
      }
    });
    Future<void> initial() async {
      final result = await _fetch();
      if (!active || current != null) return;
      switch (result) {
        case Success(:final value):
          current = value;
          controller.addSync(value);
        case Failure(:final error):
          controller.addErrorSync(error);
      }
    }

    unawaited(initial());
    controller.onCancel = () async {
      active = false;
      debounce?.cancel();
      _range = null;
      holder.cancel();
      await frames.cancel();
    };
  });

  @override
  void setVisibleRange(int fromStrike, int toStrike) =>
      _range?.call(fromStrike, toStrike);
}
