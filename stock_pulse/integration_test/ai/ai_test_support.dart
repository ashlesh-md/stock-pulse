import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/bootstrap.dart';
import 'package:stock_pulse/app/router/app_shell_scaffold.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_data_providers.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_providers.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_answer.dart';
import 'package:stock_pulse/features/ai_chat/presentation/screens/ai_chat_screen.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_view.dart';
import 'package:stock_pulse/features/orders/data/live_order_repository.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';

import '../../test/features/ai_chat/chat_fakes.dart';
import '../../test/helpers/fake_crash_reporter.dart';
import '../../test/helpers/fake_local_prefs.dart';
import '../../test/helpers/fake_snapshot_store.dart';
import '../../test/helpers/test_server.dart';

export '../../test/helpers/test_server.dart' show TestServer, eventually;

void expectLatestAnswer(ProviderContainer container, AnswerStatus status) {
  final answer = container
      .read(chatControllerProvider)
      .requireValue
      .answers
      .last;
  expect(
    answer.status,
    status,
    reason:
        'AI answer ended ${answer.status}; cards=${answer.cards.length}; '
        'error=${answer.error}',
  );
}

Future<ProviderContainer> mountAiApp(
  WidgetTester tester,
  TestServer server,
) async {
  final app = appScope(
    reporter: FakeCrashReporter(),
    snapshot: Future<AppSnapshot?>.value(),
    overrides: [
      appConfigProvider.overrideWithValue(server.config),
      snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
      localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
      chatHistoryProvider.overrideWithValue(FakeHistory()),
      orderRepositoryProvider.overrideWith((ref) {
        final repository = LiveOrderRepository(
          ref.watch(apiClientProvider),
          ref.watch(marketSocketProvider),
        );
        ref.onDispose(repository.dispose);
        return CountingOrders(repository);
      }),
    ],
  );
  await tester.pumpWidget(app);
  await tester.pump(const Duration(seconds: 1));
  final shell = find.byType(AppShellScaffold);
  await waitForWidget(tester, () => shell.evaluate().isNotEmpty);
  return ProviderScope.containerOf(tester.element(shell));
}

Future<void> askAi(
  ProviderContainer container,
  WidgetTester tester,
  String question,
) async {
  await waitForWidget(
    tester,
    () => container.read(chatControllerProvider).hasValue,
    reason: 'chat history to load',
  );
  final controller = container.read(chatControllerProvider.notifier);
  final previousCount = container
      .read(chatControllerProvider)
      .requireValue
      .answers
      .length;
  controller.ask(question);
  await tester.pump();
  await tester.pump();
  await waitForWidget(tester, () {
    final answers = container.read(chatControllerProvider).value?.answers;
    return answers != null &&
        answers.length > previousCount &&
        !answers.last.busy;
  }, reason: 'completed AI response for "$question"');
  expectLatestAnswer(container, AnswerStatus.complete);
  await tester.pump(const Duration(milliseconds: 250));
}

Finder chatList() => find
    .descendant(of: find.byType(AiChatScreen), matching: find.byType(ListView))
    .first;

Finder quoteViews() => find.byWidgetPredicate(
  (widget) => widget is AiCardView && widget.card.type == 'quote',
);

Future<void> waitForWidget(
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

Future<void> waitForServer(
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

Future<Map<String, Object?>> readDebug(HttpClient client, Uri base) async =>
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

List<String> quoteIds(Map<String, Object?> data) => [
  for (final raw in data['sessions']! as List)
    ...((raw as Map<String, Object?>)['quoteIds']! as List).cast<String>(),
];

int quoteCardCount(ProviderContainer container) => container
    .read(chatControllerProvider)
    .requireValue
    .answers
    .expand((answer) => answer.cards)
    .where((card) => card.type == 'quote')
    .length;

class CountingOrders implements OrderRepository {
  CountingOrders(this.delegate);
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
