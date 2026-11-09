import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/orders/application/order_ticket_state.dart';
import 'package:stock_pulse/features/orders/di/order_preflight_provider.dart';
import 'package:stock_pulse/features/orders/di/order_ticket_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/ticket_validation.dart';

import '../../helpers/fake_crash_reporter.dart';

void main() {
  test('every preflight block reads as its own sentence', () async {
    final texts = <String?>{};
    for (final block in TicketBlock.values) {
      final c = ProviderContainer.test(
        overrides: [
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
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
            }) => block,
          ),
        ],
      );
      final text = await c
          .read(orderTicketControllerProvider('TCS').notifier)
          .submit(side: OrderSide.buy, type: OrderType.market, quantity: 1);
      expect(text, isNotNull, reason: '$block');
      texts.add(text);
      expect(c.read(orderTicketControllerProvider('TCS')).submitting, isFalse);
    }
    expect(texts, hasLength(TicketBlock.values.length));
  });

  test('ticket states compare by value and copy', () {
    const s = OrderTicketState();
    expect(
      s.copyWith(submitting: true),
      const OrderTicketState(submitting: true),
    );
    expect(s.copyWith(uncertain: true).uncertain, isTrue);
    expect(s.copyWith(), s);
    expect(s.hashCode, const OrderTicketState().hashCode);
    expect(s, isNot(const OrderTicketState(uncertain: true)));
  });
}
