import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/l10n/strings/more_strings.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';

/// The socket's state in words, for learning how the connection behaves.
class SocketStatusText extends ConsumerWidget {
  const SocketStatusText({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(socketStatusProvider).value;
    return Text(
      describeSocket(
        context.strings.more,
        status,
        context.strings.common.noValue,
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

String describeSocket(MoreStrings s, SocketStatus? status, String noValue) =>
    switch (status) {
      SocketConnected(:final sessionId, :final latency) => s.connected(
        sessionId,
        latency == null ? noValue : '${latency.inMilliseconds} ms',
      ),
      SocketReconnecting(:final attempt, :final delay, :final reason) =>
        s.reconnecting(reason, attempt, delay.inMilliseconds),
      SocketConnecting(:final attempt) => s.connecting(attempt),
      SocketPaused() => s.paused,
      null => s.starting,
    };
