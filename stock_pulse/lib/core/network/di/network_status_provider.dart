import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';

final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final socket = ref.watch(marketSocketProvider);
  final clock = ref.watch(clockProvider);
  final api = ref.watch(apiClientProvider);
  final controller = StreamController<NetworkStatus>();
  var last = NetworkStatus.reconnecting;
  var reachable = true;
  var probing = false;
  var disposed = false;
  var checks = 0;
  final startedAt = clock.now();
  void publish() {
    final next = socket.status is SocketConnected
        ? (clock.now().difference(socket.lastFrameAt ?? startedAt) >
                  socket.config.delayedAfter
              ? NetworkStatus.delayed
              : NetworkStatus.live)
        : (reachable ? NetworkStatus.reconnecting : NetworkStatus.offline);
    if (!controller.hasListener || next != last) controller.add(next);
    last = next;
  }

  Future<void> probe() async {
    if (probing || socket.status is SocketConnected) return;
    probing = true;
    final health = await api.getHealth();
    probing = false;
    if (disposed) return;
    reachable = health is Success<void>;
    publish();
  }

  final sub = socket.statusChanges.listen((_) => publish());
  final timer = Timer.periodic(const Duration(seconds: 1), (_) {
    publish();
    if (++checks % 3 == 0) unawaited(probe());
  });
  if (socket.status is SocketConnected) last = NetworkStatus.live;
  controller.add(last);
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    unawaited(sub.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});
