import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/orders/application/order_draft.dart';
import 'package:stock_pulse/features/orders/application/order_draft_controller.dart';
import 'package:stock_pulse/features/orders/application/order_ticket_controller.dart';
import 'package:stock_pulse/features/orders/application/order_ticket_state.dart';
import 'package:stock_pulse/features/orders/application/ticket_contract.dart';

final orderTicketControllerProvider =
    NotifierProvider.family<OrderTicketController, OrderTicketState, String>(
      OrderTicketController.new,
    );

final orderDraftControllerProvider = NotifierProvider.autoDispose
    .family<OrderDraftController, OrderDraft, OrderDraftSeed>(
      OrderDraftController.new,
    );

/// The contract and a starting price for the full-screen ticket. Loaded
/// once: the ticket does not rebuild on ticks.
final ticketContractProvider = FutureProvider.autoDispose
    .family<TicketContract, String>(loadTicketContract);
