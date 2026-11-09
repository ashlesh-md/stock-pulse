import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/market/application/live_quote_provider.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/ticket_validation.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';

typedef OrderPreflight = TicketBlock? Function({
  required String symbol,
  required OrderSide side,
  required OrderType type,
  required ProductType product,
  required int quantity,
  int? lots,
  double? limitPrice,
  double? triggerPrice,
});

final orderPreflightProvider = Provider<OrderPreflight>(
  (ref) =>
      ({
        required symbol,
        required side,
        required type,
        required product,
        required quantity,
        lots,
        limitPrice,
        triggerPrice,
      }) {
        final market = ref.read(marketRepositoryProvider);
        final clock = ref.read(marketClockProvider).value;
        if (clock == null) return TicketBlock.unavailable;
        return validateTicket(
          quote: market.latest(symbol),
          instrument: market.instrument(symbol),
          clock: clock,
          serverNow: ref.read(serverClockProvider).now(),
          socketLive:
              ref.read(networkStatusProvider).value == NetworkStatus.live,
          riskAcked:
              ref.read(localPrefsProvider).value?.data.riskNoticeAcked ?? false,
          side: side,
          type: type,
          product: product,
          quantity: quantity,
          lots: lots,
          limitPrice: limitPrice,
          triggerPrice: triggerPrice,
          availableFunds: ref
              .read(portfolioRepositoryProvider)
              .current
              ?.funds
              ?.available,
        );
      },
);

typedef TicketEligibilityArgs = ({
  String symbol,
  OrderSide side,
  OrderType type,
  ProductType product,
  int quantity,
  int? lots,
  double? limitPrice,
  double? triggerPrice,
});

/// Rechecks submission eligibility as the market clock, feed and quote age
/// change so the confirm button can enable without reopening the ticket.
final orderTicketEligibilityProvider =
    Provider.family<TicketBlock?, TicketEligibilityArgs>((ref, args) {
      ref
        ..watch(marketClockProvider)
        ..watch(networkStatusProvider)
        ..watch(freshnessTickProvider)
        ..watch(liveQuoteProvider((id: args.symbol, throttleMs: 500)));
      return ref.watch(orderPreflightProvider)(
        symbol: args.symbol,
        side: args.side,
        type: args.type,
        product: args.product,
        quantity: args.quantity,
        lots: args.lots,
        limitPrice: args.limitPrice,
        triggerPrice: args.triggerPrice,
      );
    });
