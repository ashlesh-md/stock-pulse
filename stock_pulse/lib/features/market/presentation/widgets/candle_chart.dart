import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/presentation/widgets/candle_geometry.dart';
import 'package:stock_pulse/features/market/presentation/widgets/candle_painter.dart';

/// Price chart with volume bars, drawn with a [CustomPainter].
///
/// - [type]: candles, Heikin-Ashi, OHLC bars, line or area.
/// - A new range starts "fitted": every candle fits the width, like the
///   1D … 5Y views in broker apps. Pinch / scroll-wheel to zoom in, drag to
///   pan back in time, double-tap to fit again, long-press for a crosshair.
/// - [baseline] (1D: yesterday's close) is drawn as a dotted line, and line
///   and area charts are green or red depending on which side of it the
///   price is.
///
/// Give it a new `key` when the range or interval changes so zoom and pan
/// reset. Wrapped in a [RepaintBoundary]: ticks repaint only the chart layer.
class CandleChart extends StatefulWidget {
  const CandleChart({
    super.key,
    required this.candles,
    required this.interval,
    this.type = ChartType.candles,
    this.baseline,
    this.overlayBuilder,
    this.interactive = true,
    this.showVolume = true,
  });

  final List<Candle> candles;
  final CandleInterval interval;
  final ChartType type;
  final double? baseline;
  final Widget Function(double candleWidth, int offset)? overlayBuilder;

  /// false: a static picture with no zoom, pan, crosshair or focus (the
  /// mini chart inside an AI card).
  final bool interactive;
  final bool showVolume;

  @override
  State<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends State<CandleChart>
    with SingleTickerProviderStateMixin {
  /// null = fit every candle to the width. Set once the user zooms.
  double? _zoomedWidth;
  double _scaleStartWidth = 8;

  /// How many candles we are scrolled back from the newest one.
  double _offset = 0;
  int? _crosshair;
  late final AnimationController _momentum = AnimationController.unbounded(
    vsync: this,
  );
  final FocusNode _focus = FocusNode();
  double _plotWidth = 1;

  @override
  void initState() {
    super.initState();
    _momentum.addListener(() {
      final maxOffset = CandleGeometry.maxOffset(
        widget.candles.length,
        _plotWidth,
        _candleWidth(_plotWidth),
      );
      setState(() => _offset = _momentum.value.clamp(0, maxOffset));
      if (_momentum.value < 0 || _momentum.value > maxOffset) _momentum.stop();
    });
  }

  @override
  void dispose() {
    _momentum.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _zoom(double newWidth, double focalX, double plotWidth) {
    final oldWidth = _candleWidth(plotWidth);
    final width = newWidth.clamp(_minWidth, _maxWidth);
    setState(() {
      _offset = CandleGeometry.anchoredOffset(
        widget.candles.length,
        plotWidth,
        oldWidth: oldWidth,
        newWidth: width,
        offset: _offset,
        focalX: focalX,
      );
      _zoomedWidth = width;
    });
  }

  void _pan(double pixels, double plotWidth) => setState(() {
    final width = _candleWidth(plotWidth);
    _offset = (_offset + pixels / width).clamp(
      0,
      CandleGeometry.maxOffset(widget.candles.length, plotWidth, width),
    );
  });

  double get _minWidth => CandleGeometry.minCandleWidth(widget.type);
  static const _maxWidth = CandleGeometry.maxCandleWidth;

  double _candleWidth(double plotWidth) =>
      _zoomedWidth ??
      CandleGeometry.fitWidth(plotWidth, widget.candles.length, widget.type);

  @override
  Widget build(BuildContext context) {
    // Heikin-Ashi is a different view of the same data: computed here, per
    // build, from the real candles (2,000 candles take well under 1 ms).
    final drawn = widget.type == ChartType.heikinAshi
        ? heikinAshi(widget.candles)
        : widget.candles;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotWidth = constraints.maxWidth - CandleGeometry.axisWidth;
          final width = _candleWidth(plotWidth);
          _plotWidth = plotWidth;
          final painted = _paint(context, constraints, drawn, width);
          if (!widget.interactive) return painted;

          return Focus(
            focusNode: _focus,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _pan(width * 5, plotWidth);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _pan(-width * 5, plotWidth);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Listener(
              // The chart claims the wheel event so the page does not also
              // scroll: wheel pans, Ctrl or Cmd + wheel zooms.
              onPointerSignal: (e) {
                if (e is! PointerScrollEvent) return;
                GestureBinding.instance.pointerSignalResolver.register(e, (_) {
                  final zoom =
                      HardwareKeyboard.instance.isControlPressed ||
                      HardwareKeyboard.instance.isMetaPressed;
                  if (zoom) {
                    _zoom(
                      width * (e.scrollDelta.dy > 0 ? 0.9 : 1.1),
                      e.localPosition.dx,
                      plotWidth,
                    );
                    return;
                  }
                  final delta = e.scrollDelta.dx != 0
                      ? e.scrollDelta.dx
                      : e.scrollDelta.dy;
                  _pan(-delta, plotWidth);
                });
              },
              child: GestureDetector(
                onTap: _focus.requestFocus,
                onScaleStart: (_) {
                  _momentum.stop();
                  _focus.requestFocus();
                  _scaleStartWidth = width;
                },
                onScaleUpdate: (d) {
                  if (d.scale != 1) {
                    _zoom(
                      _scaleStartWidth * d.scale,
                      d.localFocalPoint.dx,
                      plotWidth,
                    );
                  }
                  _pan(d.focalPointDelta.dx, plotWidth);
                },
                onScaleEnd: (d) {
                  final velocity =
                      d.velocity.pixelsPerSecond.dx / _candleWidth(plotWidth);
                  if (velocity.abs() > 5) {
                    _momentum
                        .animateWith(
                          FrictionSimulation(0.12, _offset, velocity),
                        )
                        .ignore();
                  }
                },
                onDoubleTap: () => setState(() {
                  _zoomedWidth = null; // back to "fit"
                  _offset = 0;
                  _momentum.stop();
                }),
                onLongPressStart: (d) =>
                    _updateCrosshair(d.localPosition.dx, plotWidth, width),
                onLongPressMoveUpdate: (d) =>
                    _updateCrosshair(d.localPosition.dx, plotWidth, width),
                onLongPressEnd: (_) => setState(() => _crosshair = null),
                child: painted,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _paint(
    BuildContext context,
    BoxConstraints constraints,
    List<Candle> drawn,
    double width,
  ) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: CandlePainter(
            candles: drawn,
            type: widget.type,
            interval: widget.interval,
            baseline: widget.baseline,
            candleWidth: width,
            offset: _offset.round(),
            crosshair: _crosshair,
            gridColor: theme.dividerColor.withValues(alpha: 0.4),
            textStyle: theme.textTheme.labelSmall!.copyWith(
              color: theme.hintColor,
            ),
            labelBackground: theme.colorScheme.surfaceContainerHighest,
            colors: context.sp,
            strings: context.strings.market,
            showVolume: widget.showVolume,
          ),
        ),
        if (widget.overlayBuilder != null)
          IgnorePointer(child: widget.overlayBuilder!(width, _offset.round())),
      ],
    );
  }

  void _updateCrosshair(double dx, double plotWidth, double width) {
    final index = CandleGeometry.indexAt(
      dx,
      widget.candles.length,
      plotWidth,
      width,
      _offset.round(),
    );
    setState(() => _crosshair = index);
  }
}
