import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/widgets/error_view.dart';
import 'package:stock_pulse/core/widgets/segmented_choice.dart';
import 'package:stock_pulse/core/widgets/sp_tab_app_bar.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/portfolio_list.dart';

/// Positions, holdings and today's orders. The screen selects only load
/// state; rows select their own prices.
class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({
    super.key,
    this.initialSection = PortfolioSection.positions,
  });
  final PortfolioSection initialSection;

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  late PortfolioSection _section = widget.initialSection;

  @override
  void initState() {
    super.initState();
    _loadSection();
  }

  @override
  void didUpdateWidget(PortfolioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSection != oldWidget.initialSection) {
      _section = widget.initialSection;
      _loadSection();
    }
  }

  void _loadSection() {
    if (_section != PortfolioSection.holdings) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(portfolioControllerProvider.future);
      if (mounted && _section == PortfolioSection.holdings) {
        await ref.read(portfolioControllerProvider.notifier).loadHoldings();
      }
    });
  }

  Future<void> _refresh() async {
    final controller = ref.read(portfolioControllerProvider.notifier);
    await controller.refresh();
    if (mounted && _section == PortfolioSection.holdings) {
      await controller.loadHoldings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline =
        ref.watch(networkStatusProvider).asData?.value == NetworkStatus.offline;
    final (hasValue, error) = ref.watch(
      portfolioControllerProvider.select((a) => (a.hasValue, a.error)),
    );
    final strings = context.strings.portfolio;
    return Scaffold(
      appBar: SpTabAppBar(title: Text(strings.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedChoice<PortfolioSection>(
              segments: [
                SpSegment(PortfolioSection.positions, strings.positions),
                SpSegment(PortfolioSection.holdings, strings.holdings),
                SpSegment(PortfolioSection.orders, strings.orders),
              ],
              selected: _section,
              onChanged: (section) {
                setState(() => _section = section);
                _loadSection();
              },
            ),
          ),
          Expanded(
            child: switch ((hasValue, error)) {
              (true, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, .025),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: RefreshIndicator(
                  key: ValueKey(_section),
                  onRefresh: _refresh,
                  child: PortfolioList(
                    section: _section,
                    refreshEnabled: !offline,
                  ),
                ),
              ),
              (false, final Object error) => ErrorView(
                error: error,
                onRetry: _refresh,
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}
