import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/options/di/options_providers.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_column.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_row_tile.dart';
import 'package:stock_pulse/features/options/presentation/widgets/chain_target.dart';

/// The strike rows. Opens with the ATM row at about 55 % of the height,
/// never auto-scrolls after that, offers Back to ATM while the ATM row is
/// off screen, and narrows the live feed to the rows on screen.
class ChainList extends ConsumerStatefulWidget {
  const ChainList({
    super.key,
    required this.target,
    required this.strikes,
    required this.atm,
    required this.columns,
  });

  final ChainTarget target;
  final List<int> strikes;
  final int atm;
  final Set<ChainColumn> columns;

  /// Rows past the screen edge still streamed, so a short scroll is live.
  static const buffer = 5;

  @override
  ConsumerState<ChainList> createState() => _ChainListState();
}

class _ChainListState extends ConsumerState<ChainList> {
  ScrollController? _scroll;
  bool _atmVisible = true;
  double _viewport = 0;
  late int _currentAtm;

  @override
  void initState() {
    super.initState();
    _currentAtm = widget.atm;
  }

  int get _atmIndex => widget.strikes.indexOf(_currentAtm);

  bool _isAtmVisible(double top, double viewport) {
    final atmTop = _atmIndex * SpDensity.chainRow;
    return atmTop + SpDensity.chainRow > top && atmTop < top + viewport;
  }

  double _offsetFor(int index, double viewport) =>
      (index * SpDensity.chainRow - viewport * .55 + SpDensity.chainRow / 2)
          .clamp(0, double.infinity)
          .toDouble();

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    final top = n.metrics.pixels;
    final bottom = top + n.metrics.viewportDimension;
    final visible = _isAtmVisible(top, n.metrics.viewportDimension);
    if (visible != _atmVisible) setState(() => _atmVisible = visible);
    if (n is ScrollEndNotification) _narrowFeed(top, bottom);
    return false;
  }

  void _narrowFeed(double top, double bottom) {
    final strikes = widget.strikes;
    final first = (top / SpDensity.chainRow).floor() - ChainList.buffer;
    final last = (bottom / SpDensity.chainRow).ceil() + ChainList.buffer;
    ref
        .read(chainControllerProvider(widget.target).notifier)
        .setVisibleRange(
          strikes[first.clamp(0, strikes.length - 1)],
          strikes[last.clamp(0, strikes.length - 1)],
        );
  }

  Future<void> _backToAtm() => _scroll!.animateTo(
    _offsetFor(_atmIndex, _viewport),
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(
      chainControllerProvider(widget.target)
          .select((state) => state.value?.view?.atm),
      (_, next) {
        if (next == null || next == _currentAtm) return;
        _currentAtm = next;
        final scroll = _scroll;
        if (scroll == null || !_viewport.isFinite) return;
        final visible = _isAtmVisible(scroll.offset, _viewport);
        if (visible != _atmVisible && mounted) {
          setState(() => _atmVisible = visible);
        }
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.maxHeight;
        final scroll = _scroll ??= ScrollController(
          initialScrollOffset: _offsetFor(_atmIndex, _viewport),
        );
        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ListView.builder(
                controller: scroll,
                itemExtent: SpDensity.chainRow,
                itemCount: widget.strikes.length,
                itemBuilder: (context, index) => ChainRowTile(
                  key: ValueKey(widget.strikes[index]),
                  target: widget.target,
                  strike: widget.strikes[index],
                  columns: widget.columns,
                ),
              ),
            ),
            if (!_atmVisible)
              Positioned(
                right: SpSpace.gutter,
                bottom: SpSpace.gutter,
                child: FloatingActionButton.extended(
                  heroTag: null,
                  onPressed: _backToAtm,
                  icon: const Icon(AppIcons.target),
                  label: Text(context.strings.options.backToAtm),
                ),
              ),
          ],
        );
      },
    );
  }
}
