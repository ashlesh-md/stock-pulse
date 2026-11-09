import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/connection_badge.dart';
import 'package:stock_pulse/core/widgets/error_view.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/presentation/widgets/range_bar.dart';
import 'package:stock_pulse/features/market/presentation/widgets/stock_chart.dart';
import 'package:stock_pulse/features/market/presentation/widgets/stock_chart_toolbar.dart';
import 'package:stock_pulse/features/market/presentation/widgets/stock_depth.dart';
import 'package:stock_pulse/features/market/presentation/widgets/stock_header.dart';
import 'package:stock_pulse/features/market/presentation/widgets/stock_stats.dart';
import 'package:stock_pulse/features/market/presentation/widgets/trade_bar.dart';

/// Quote header, live chart, stats, order book and buy/sell. Each section
/// selects only what it shows, so a depth update does not repaint the chart.
class StockDetailScreen extends ConsumerStatefulWidget {
  const StockDetailScreen({
    super.key,
    required this.instrumentId,
    this.isExternalLink = false,
  });

  final String instrumentId;
  final bool isExternalLink;

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  bool _invalidInstrumentHandled = false;

  @override
  Widget build(BuildContext context) {
    final provider = stockDetailControllerProvider(widget.instrumentId);
    ref.listen(provider, (previous, next) {
      final error = next.error;
      if (!widget.isExternalLink ||
          _invalidInstrumentHandled ||
          error is! ServerError ||
          error.statusCode != 404) {
        return;
      }
      _invalidInstrumentHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(feedbackControllerProvider.notifier)
            .show(
              FeedbackMessage(
                key: 'links.not_available',
                text: context.strings.common.linkNotAvailable,
              ),
            );
        context.goTo(const WatchlistRoute());
      });
    });
    // Rebuilds only when loading, error or data switches, not on ticks.
    final (hasData, error, kind) = ref.watch(
      provider.select((s) => (s.hasValue, s.error, s.value?.instrument.kind)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.instrumentId),
        actions: const [ConnectionBadge()],
      ),
      body: switch ((hasData, error, kind)) {
        (true, _, _) => _sections(
          context,
          showMarketDepth: kind != InstrumentKind.marketIndex,
        ),
        (false, final Object error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(provider.notifier).retry(),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: hasData
          ? TradeBar(instrumentId: widget.instrumentId)
          : null,
    );
  }

  Widget _sections(
    BuildContext context, {
    required bool showMarketDepth,
  }) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 8),
    children: [
      StockHeader(instrumentId: widget.instrumentId),
      const SizedBox(height: 8),
      StockChartToolbar(instrumentId: widget.instrumentId),
      SizedBox(
        height: 320,
        child: StockChart(instrumentId: widget.instrumentId),
      ),
      RangeBar(instrumentId: widget.instrumentId),
      const Divider(height: 24),
      StockStats(instrumentId: widget.instrumentId),
      const Divider(height: 24),
      if (showMarketDepth) ...[StockDepth(instrumentId: widget.instrumentId)],
      const SizedBox(height: 80),
    ],
  );
}
