import 'dart:async';

import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/market_time/data/clock_api.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';

class ClockRepository {
  ClockRepository([this._api, this._socket]);
  final ApiClient? _api;
  final MarketSocket? _socket;

  Stream<MarketClockState> watch() => Stream.multi((controller) {
    var active = true;
    var receivedFrame = false;
    final socket = _socket;
    final sub = socket?.messages
        .where((m) => m['type'] == 'clock' || m['type'] == 'welcome')
        .listen((m) {
          final data = m['type'] == 'welcome' ? m['clock'] : m;
          if (data is! Map<String, Object?>) return;
          final parsed = parseJson(() => MarketClockState.fromJson(data));
          if (parsed case Success(:final value)) {
            receivedFrame = true;
            controller.addSync(value);
          }
        });
    Future<void> initial() async {
      final api = _api;
      if (api == null) {
        controller.addSync(MarketClockState.fallback);
        return;
      }
      final result = await api.call(clockEndpoint);
      if (!active || receivedFrame) return;
      final parsed = switch (result) {
        Success(value: final Map<String, Object?> data) => parseJson(
          () => MarketClockState.fromJson(data),
        ),
        _ => null,
      };
      // Until the socket sends a clock, screens still need a phase.
      controller.addSync(switch (parsed) {
        Success(:final value) => value,
        _ => MarketClockState.fallback,
      });
    }

    unawaited(initial());
    controller.onCancel = () async {
      active = false;
      await sub?.cancel();
    };
  });
}
