import 'package:flutter/foundation.dart';

import 'package:stock_pulse/core/network/domain/socket_ops.dart';

/// Where the market server runs.
///
/// Pass `--dart-define=SERVER_HOST=192.168.1.20` to use a phone on Wi-Fi.
/// Otherwise: the Android emulator reaches the host Mac at 10.0.2.2; every
/// other target (iOS simulator, macOS, web) uses localhost.
class AppConfig {
  const AppConfig({
    required this.host,
    this.port = 8080,
    this.token = 'demo-token',
  });

  factory AppConfig.fromEnvironment() {
    const fromDefine = String.fromEnvironment('SERVER_HOST');
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return AppConfig(
      host: fromDefine.isNotEmpty
          ? fromDefine
          : (isAndroid ? '10.0.2.2' : 'localhost'),
    );
  }

  final String host;
  final int port;

  /// Session token. A real app gets it from login and keeps it in secure
  /// storage; the demo server accepts only this value.
  final String token;

  Uri get restBase => Uri(scheme: 'http', host: host, port: port);

  /// `ws://` is plain WebSocket; production uses `wss://` (TLS), just as
  /// REST uses https. The token goes in the query string because browsers
  /// cannot set headers on a WebSocket handshake.
  Uri get socketUri => Uri(
    scheme: 'ws',
    host: host,
    port: port,
    path: socketPath,
    queryParameters: {'token': token},
  );
}
