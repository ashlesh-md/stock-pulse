import 'package:stock_pulse/core/l10n/strings/order_strings.dart';
import 'package:stock_pulse/features/orders/domain/ticket_validation.dart';

/// The user-facing reason an order cannot be sent yet.
String ticketBlockMessage(OrderStrings strings, TicketBlock block) =>
    switch (block) {
      TicketBlock.unavailable => strings.blockUnavailable,
      TicketBlock.closed => strings.blockClosed,
      TicketBlock.preOpen => strings.blockPreOpen,
      TicketBlock.instrument => strings.rejectedSymbol,
      TicketBlock.quantity => strings.rejectedQuantity,
      TicketBlock.price => strings.rejectedPrice,
      TicketBlock.trigger => strings.blockTrigger,
      TicketBlock.product => strings.blockProduct,
      TicketBlock.expired => strings.blockExpired,
      TicketBlock.cutoff => strings.blockCutoff,
      TicketBlock.risk => strings.blockRisk,
      TicketBlock.funds => strings.blockFunds,
    };
