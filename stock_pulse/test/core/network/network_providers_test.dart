import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';

import '../../helpers/fake_crash_reporter.dart';

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

  test('a frame the app cannot read is dropped and logged once', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final ws = await WebSocketTransformer.upgrade(request);
      addTearDown(ws.close);
      ws
        ..add('not json')
        ..add('also not json');
    });
    final reporter = FakeCrashReporter();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(host: '127.0.0.1', port: server.port),
        ),
        crashReporterProvider.overrideWithValue(reporter),
      ],
    );
    addTearDown(container.dispose);

    container.read(marketSocketProvider);
    for (
      var i = 0;
      i < 50 && reporter.logsNamed('socket_frame_dropped').isEmpty;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final dropped = reporter.logsNamed('socket_frame_dropped');
    expect(dropped, hasLength(1));
    expect(dropped.single.data, {'reason': 'not_json'});
  });
}
