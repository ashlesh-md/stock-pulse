import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_server/market_server.dart' show demoToken;
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/orders/di/order_preflight_provider.dart';
import 'package:stock_pulse/features/orders/di/order_ticket_providers.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';

import '../../helpers/fake_crash_reporter.dart';
import '../../helpers/fake_local_prefs.dart';
import '../../helpers/fake_market_socket.dart';
import '../../helpers/fake_pending_order_store.dart';
import '../../helpers/test_server.dart';

void main() {
  test(
    'a stored order with a dropped acknowledgement is reconciled once',
    () async {
      final server = await TestServer.start(debug: true);
      final debugClient = HttpClient();
      addTearDown(() async {
        debugClient.close(force: true);
        await server.close();
      });

      final request = await debugClient.postUrl(
        Uri.http('127.0.0.1:${server.config.port}', '/debug/faults'),
      );
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $demoToken')
        ..contentType = ContentType.json;
      request.write(
        jsonEncode({
          'path': '/api/v1/orders',
          'method': 'POST',
          'dropAckAfterStore': true,
        }),
      );
      final configured = await request.close();
      expect(configured.statusCode, 200);
      await configured.drain<void>();

      final container = ProviderContainer.test(
        overrides: [
          appConfigProvider.overrideWithValue(server.config),
          marketSocketProvider.overrideWithValue(FakeMarketSocket()),
          localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
          pendingOrderStoreProvider.overrideWith(
            (ref) async => FakePendingOrderStore(),
          ),
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
          analyticsProvider.overrideWithValue(
            AnalyticsService(
              const [],
              FakeCrashReporter(),
              consent: () => false,
            ),
          ),
          orderPreflightProvider.overrideWithValue(
            ({
              required symbol,
              required side,
              required type,
              required product,
              required quantity,
              lots,
              limitPrice,
              triggerPrice,
            }) => null,
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(orderTicketControllerProvider('TCS').notifier)
          .submit(side: OrderSide.buy, type: OrderType.market, quantity: 1);

      expect(result, isNull);
      expect(server.server.broker.orders, hasLength(1));
      final orders = await container.read(orderRepositoryProvider).getOrders();
      expect(orders, isA<Success<List<Order>>>());
      expect((orders.valueOrNull!).single.clientKey, isNotNull);
    },
  );
}
