import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/http_debug_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/data/secure_idempotency_keys.dart';
import 'package:stock_pulse/core/network/domain/debug_client.dart';
import 'package:stock_pulse/core/network/domain/idempotency_keys.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';

// Plain `Provider`s: created once and kept for the app's life, which is what
// a socket and an HTTP client need. Tests override `appConfigProvider`.

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(appConfigProvider));
  ref.onDispose(client.close);
  return client;
});

/// One socket for the whole app: one per screen would mean several
/// connections, duplicate data and more battery.
final marketSocketProvider = Provider<MarketSocket>((ref) {
  final socket = MarketSocket(
    ref.watch(appConfigProvider).socketUri,
    clock: ref.watch(clockProvider),
    serverClock: ref.watch(serverClockProvider),
  )..start();
  ref.onDispose(socket.dispose);
  return socket;
});

final debugClientProvider = Provider<DebugClient>(
  (ref) => HttpDebugClient(ref.watch(apiClientProvider)),
);

final idempotencyKeysProvider = Provider<IdempotencyKeys>(
  (ref) => SecureIdempotencyKeys(),
);

final socketStatusProvider = StreamProvider<SocketStatus>((ref) async* {
  final socket = ref.watch(marketSocketProvider);
  yield socket.status;
  yield* socket.statusChanges;
});
