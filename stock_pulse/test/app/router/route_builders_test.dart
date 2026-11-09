import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/features/more/data/debug_api.dart';
import 'package:stock_pulse/features/more/data/funds_transfer_api.dart';
import 'package:stock_pulse/features/more/di/more_data_providers.dart';
import 'package:stock_pulse/features/orders/presentation/screens/order_ticket_screen.dart';
import 'package:stock_pulse/features/strategy/presentation/screens/strategy_builder_screen.dart';

import '../app_harness.dart';

void main() {
  late AppHarness h;
  setUp(() => h = AppHarness());

  testWidgets('a scheme link is normalised; a foreign one opens the '
      'watchlist', (tester) async {
    await h.pumpPhone(tester);
    h.router(tester).go('stockpulse://app/portfolio');
    await tester.pumpAndSettle();
    expect(h.router(tester).state.uri.path, '/portfolio');
    h.router(tester).go('https://evil.example/portfolio');
    await tester.pumpAndSettle();
    expect(h.router(tester).state.uri.path, '/watchlist');
  });

  testWidgets('order ticket and strategy routes build their screens', (
    tester,
  ) async {
    await h.pumpPhone(tester);
    final router = h.router(tester)..go('/order/RELIANCE');
    await tester.pumpAndSettle();
    expect(find.byType(OrderTicketScreen), findsOneWidget);
    router.go('/strategy');
    await tester.pumpAndSettle();
    expect(find.byType(StrategyBuilderScreen), findsOneWidget);
  });

  test('More data providers build the HTTP implementations', () {
    final c = ProviderContainer.test();
    expect(c.read(apiClientProvider), isNotNull);
    expect(c.read(fundsTransferProvider), isA<FundsTransferApi>());
    expect(c.read(chaosTriggerProvider), isA<DebugChaosTrigger>());
  });
}
