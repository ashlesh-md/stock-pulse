import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/feedback/presentation/feedback_host.dart';
import 'package:stock_pulse/core/platform/di/platform_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/order_update_listener.dart';

import '../helpers/fake_crash_reporter.dart';
import '../helpers/fake_haptics.dart';
import '../helpers/fake_local_prefs.dart';

class MockPortfolioRepository extends Mock implements PortfolioRepository {}

final placed = DateTime.utc(2026, 11, 4, 5);

Order order(
  OrderStatus status, {
  Duration after = Duration.zero,
  OrderType type = OrderType.limit,
}) => Order(
  id: 'ORD000002',
  symbol: 'TCS',
  side: OrderSide.buy,
  type: type,
  quantity: 10,
  status: status,
  limitPrice: 3050,
  averagePrice: status == OrderStatus.complete ? 3049.95 : null,
  createdAt: placed,
  updatedAt: placed.add(after),
);

void main() {
  late StreamController<Order> updates;
  late FakeHaptics haptics;

  Future<void> pumpApp(
    WidgetTester tester, {
    List<Order> initialOrders = const [],
    Completer<Result<List<Order>>>? initialOrdersCompleter,
    bool hapticsEnabled = true,
  }) async {
    final repo = MockPortfolioRepository();
    haptics = FakeHaptics();
    final prefs = FakeLocalPrefs(
      LocalPrefsData.defaults.copyWith(hapticsEnabled: hapticsEnabled),
    );
    Future<LocalPrefs> loadPrefs(Ref ref) async => prefs;
    updates = StreamController<Order>.broadcast();
    addTearDown(updates.close);
    when(() => repo.orderUpdates).thenAnswer((_) => updates.stream);
    when(repo.getOrders).thenAnswer(
      (_) =>
          initialOrdersCompleter?.future ??
          Future.value(Success(initialOrders)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsProvider.overrideWithValue(
            AnalyticsService(
              const [],
              FakeCrashReporter(),
              consent: () => false,
            ),
          ),
          portfolioRepositoryProvider.overrideWithValue(repo),
          hapticsProvider.overrideWithValue(haptics),
          localPrefsProvider.overrideWith(loadPrefs),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              FeedbackHost(child: OrderUpdateListener(child: child!)),
          home: const Scaffold(body: Text('any screen')),
        ),
      ),
    );
  }

  testWidgets(
    'a limit order that fills later is announced on the current screen',
    (tester) async {
      await pumpApp(tester);
      updates.add(
        order(OrderStatus.complete, after: const Duration(seconds: 40)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('ORD000002: BUY 10 TCS filled @ ₹3,049.95'),
        findsOneWidget,
      );
      expect(haptics.calls, ['success']);
    },
  );

  testWidgets('a cancel is announced', (tester) async {
    await pumpApp(tester);
    updates.add(
      order(OrderStatus.cancelled, after: const Duration(seconds: 5)),
    );
    await tester.pumpAndSettle();
    expect(find.text('ORD000002: BUY 10 TCS cancelled'), findsOneWidget);
    expect(haptics.calls, isEmpty);
  });

  testWidgets(
    'no duplicate notice for a market order that filled instantly, or a just-placed open order',
    (tester) async {
      await pumpApp(tester);
      updates
        ..add(
          order(OrderStatus.complete, type: OrderType.market),
        ) // updatedAt == createdAt
        ..add(order(OrderStatus.open));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('rejection announces and plays one rejection haptic', (
    tester,
  ) async {
    await pumpApp(tester);
    updates.add(order(OrderStatus.rejected, after: const Duration(seconds: 5)));
    await tester.pumpAndSettle();
    expect(find.text('ORD000002: BUY 10 TCS rejected'), findsOneWidget);
    expect(haptics.calls, ['rejection']);
  });

  testWidgets('duplicate outcome after resync is ignored', (tester) async {
    final filled = order(
      OrderStatus.complete,
      after: const Duration(seconds: 5),
    );
    await pumpApp(tester, initialOrders: [filled]);
    await tester.pump();
    updates.add(filled);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(haptics.calls, isEmpty);
  });

  testWidgets('updates received before the initial order snapshot are queued', (
    tester,
  ) async {
    final snapshot = Completer<Result<List<Order>>>();
    await pumpApp(tester, initialOrdersCompleter: snapshot);
    updates.add(order(OrderStatus.complete, after: const Duration(seconds: 5)));
    await tester.pump();
    snapshot.complete(const Success([]));
    await tester.pumpAndSettle();
    expect(
      find.text('ORD000002: BUY 10 TCS filled @ ₹3,049.95'),
      findsOneWidget,
    );
    expect(haptics.calls, ['success']);
  });

  testWidgets('duplicate live outcomes only announce and vibrate once', (
    tester,
  ) async {
    await pumpApp(tester);
    final filled = order(
      OrderStatus.complete,
      after: const Duration(seconds: 5),
    );
    updates
      ..add(filled)
      ..add(filled);
    await tester.pumpAndSettle();
    expect(
      find.text('ORD000002: BUY 10 TCS filled @ ₹3,049.95'),
      findsOneWidget,
    );
    expect(haptics.calls, ['success']);
  });

  testWidgets('disabled haptics preference suppresses outcome vibration', (
    tester,
  ) async {
    await pumpApp(tester, hapticsEnabled: false);
    updates.add(order(OrderStatus.complete, after: const Duration(seconds: 5)));
    await tester.pumpAndSettle();
    expect(
      find.text('ORD000002: BUY 10 TCS filled @ ₹3,049.95'),
      findsOneWidget,
    );
    expect(haptics.calls, isEmpty);
  });
}
