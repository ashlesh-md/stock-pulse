import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';

void main() {
  test('the app config comes from the environment by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(appConfigProvider).socketUri,
      AppConfig.fromEnvironment().socketUri,
    );
  });

  test(
    'the socket starts on first read and is disposed with the container',
    () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(host: '127.0.0.1', port: 9),
          ),
        ],
      );
      final socket = container.read(marketSocketProvider);
      final statuses = <SocketStatus>[];
      final done = Completer<void>();
      socket.statusChanges.listen(statuses.add, onDone: done.complete);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      container.dispose();
      await done.future;
      expect(statuses.whereType<SocketReconnecting>(), isNotEmpty);
    },
  );
}
