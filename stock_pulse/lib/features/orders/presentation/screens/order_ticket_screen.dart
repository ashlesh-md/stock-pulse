import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/error_view.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/presentation/widgets/order_sheet.dart';
import 'package:stock_pulse/features/orders/application/ticket_contract.dart';
import 'package:stock_pulse/features/orders/di/order_ticket_providers.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/option_risk_gate.dart';

/// Full-screen ticket for deep links, the chain and AI cards. It loads the
/// contract once and never rebuilds on ticks.
class OrderTicketScreen extends ConsumerStatefulWidget {
  const OrderTicketScreen({super.key, required this.args});
  final OrderTicketArgs args;

  @override
  ConsumerState<OrderTicketScreen> createState() => _OrderTicketScreenState();
}

class _OrderTicketScreenState extends ConsumerState<OrderTicketScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(analyticsProvider)
            .log(Events.orderSheetOpened(widget.args.source.name));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final provider = ticketContractProvider(args.instrumentId);
    final contract = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.orders.ticketTitle(args.instrumentId)),
      ),
      body: switch (contract) {
        AsyncData(:final value) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _ticket(value, args),
            ),
          ),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(provider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _ticket(TicketContract contract, OrderTicketArgs args) {
    final instrument = contract.instrument;
    final sheet = OrderSheet(
      seed: (
        args: args,
        lotSize: instrument.lotSize,
        tickSize: instrument.tickSize,
        ltp: contract.ltp,
      ),
    );
    return instrument.kind == InstrumentKind.option
        ? OptionRiskGate(child: sheet)
        : sheet;
  }
}
