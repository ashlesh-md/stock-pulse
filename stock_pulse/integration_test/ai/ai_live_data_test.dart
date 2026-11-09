import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_pulse/app/bootstrap.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_shell.dart';
import 'package:stock_pulse/features/orders/data/live_order_repository.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';
import 'package:stock_pulse/features/orders/presentation/screens/order_ticket_screen.dart';
import 'package:stock_pulse/features/strategy/presentation/screens/strategy_builder_screen.dart';

import '../../test/helpers/fake_crash_reporter.dart';
import '../../test/helpers/fake_local_prefs.dart';
import '../../test/helpers/fake_snapshot_store.dart';
import '../../test/helpers/test_server.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two visible RELIANCE cards share one quote subscription and '
      'release it when scrolled away', (tester) async {
    final server = await TestServer.start(debug: true);
    addTearDown(server.close);
    _CountingOrders.reset();
    final client = HttpClient();
    addTearDown(client.close);
    final container = await _mount(tester, server);
    final router = container.read(goRouterProvider);
    router.go(const AiChatRoute().location);
    await tester.pumpAndSettle();

    await _ask(tester, 'Quote RELIANCE');
    await _waitFor(
      tester,
      () => find.byType(AiCardShell).evaluate().isNotEmpty,
    );
    await _ask(tester, 'Quote RELIANCE');
    await _waitFor(
      tester,
      () => find.byType(AiCardShell).evaluate().length >= 2,
    );
    await _waitForServer(
      tester,
      client,
      server.config.restBase.resolve('/debug/subscriptions'),
      (data) => _quoteIds(data).contains('RELIANCE'),
      'RELIANCE quote subscription',
    );
    final active = await _readDebug(client, server.config.restBase);
    expect(_quoteIds(active).where((id) => id == 'RELIANCE'), hasLength(1));

    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 450));
    await _waitForServer(
      tester,
      client,
      server.config.restBase.resolve('/debug/subscriptions'),
      (data) => !_quoteIds(data).contains('RELIANCE'),
      'RELIANCE quote release after both cards leave the viewport',
    );
  });

  testWidgets('NIFTY chain AI flow opens payoff and a source-tagged ticket '
      'without placing an order', (tester) async {
    final server = await TestServer.start(debug: true);
    addTearDown(server.close);
    final container = await _mount(tester, server);
    final router = container.read(goRouterProvider);
    router.go(const AiChatRoute().location);
    await tester.pumpAndSettle();

    await tester.tap(find.text('What does the NIFTY chain say?'));
    await _waitFor(
      tester,
      () => find.text('Trade this strike').evaluate().isNotEmpty,
    );
    expect(find.byType(AiCardShell), findsAtLeastNWidgets(2));
    await tester.tap(find.text('Payoff of a NIFTY straddle'));
    await _waitFor(
      tester,
      () => find.text('View payoff').evaluate().isNotEmpty,
    );
    await tester.ensureVisible(find.text('View payoff'));
    await tester.tap(find.text('View payoff'));
    await _waitFor(
      tester,
      () => find.byType(StrategyBuilderScreen).evaluate().isNotEmpty,
    );
    expect(find.textContaining('Max loss'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Trade this strike'));
    await tester.tap(find.text('Trade this strike'));
    await _waitFor(
      tester,
      () => find.byType(OrderTicketScreen).evaluate().isNotEmpty,
    );
    final ticket = tester.widget<OrderTicketScreen>(
      find.byType(OrderTicketScreen),
    );
    expect(ticket.args.source, OrderSource.ai);
    expect(_CountingOrders.postCount, 0);
  });
}

Future<ProviderContainer> _mount(WidgetTester tester, TestServer server) async {
  final app = appScope(
    reporter: FakeCrashReporter(),
    snapshot: Future<AppSnapshot?>.value(),
    overrides: [
      appConfigProvider.overrideWithValue(server.config),
      snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
      localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
      orderRepositoryProvider.overrideWith((ref) {
        final repository = LiveOrderRepository(
          ref.watch(apiClientProvider),
          ref.watch(marketSocketProvider),
        );
        ref.onDispose(repository.dispose);
        return _CountingOrders(repository);
      }),
    ],
  );
  await tester.pumpWidget(app);
  await tester.pump(const Duration(seconds: 1));
  final scope = find.byType(ProviderScope).first;
  return ProviderScope.containerOf(tester.element(scope));
}

Future<void> _ask(WidgetTester tester, String question) async {
  final field = find.byType(TextField).last;
  await tester.enterText(field, question);
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
  await _waitFor(
    tester,
    () =>
        find.text(question).evaluate().isNotEmpty &&
        find.byTooltip('Send').evaluate().isNotEmpty,
  );
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() ready, {
  String reason = 'widget state',
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    if (ready()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for $reason');
}

Future<void> _waitForServer(
  WidgetTester tester,
  HttpClient client,
  Uri uri,
  bool Function(Map<String, Object?>) ready,
  String reason,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    final data = await tester.runAsync(() => _getJson(client, uri));
    if (data != null && ready(data)) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('Timed out waiting for $reason');
}

Future<Map<String, Object?>> _readDebug(HttpClient client, Uri base) async =>
    _getJson(client, base.resolve('/debug/subscriptions'));

Future<Map<String, Object?>> _getJson(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri);
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer demo-token');
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw StateError('GET $uri returned ${response.statusCode}');
  }
  return jsonDecode(await utf8.decodeStream(response)) as Map<String, Object?>;
}

List<String> _quoteIds(Map<String, Object?> data) => [
  for (final raw in data['sessions']! as List)
    ...(raw as Map<String, Object?>)['quoteIds']! as List<String>,
];

class _CountingOrders implements OrderRepository {
  _CountingOrders(this.delegate);
  final OrderRepository delegate;

  @override
  Future<PlaceOutcome> place(
    OrderRequest request, {
    required String idempotencyKey,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _orderPosts++;
    return delegate.place(
      request,
      idempotencyKey: idempotencyKey,
      timeout: timeout,
    );
  }

  static int _orderPosts = 0;
  static int get postCount => _orderPosts;
  static void reset() => _orderPosts = 0;

  @override
  Future<Result<Order?>> getOrder({String? id, String? clientKey}) =>
      delegate.getOrder(id: id, clientKey: clientKey);

  @override
  Future<Result<List<Order>>> getOrders() => delegate.getOrders();

  @override
  Future<Result<Order>> cancel(String id) => delegate.cancel(id);

  @override
  Stream<Order> get updates => delegate.updates;

  @override
  Stream<void> get resyncCompleted => delegate.resyncCompleted;
}
