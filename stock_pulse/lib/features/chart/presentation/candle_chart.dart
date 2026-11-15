import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:stock_pulse/features/chart/presentation/candle_geometry.dart';
import 'package:stock_pulse/features/chart/presentation/chart_canvas.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

/// Interactive OHLCV chart with pan, zoom, crosshair and baseline support.
/// Use a new key when range or interval changes to reset its viewport.
class CandleChart extends StatefulWidget {
  const CandleChart({
    super.key,
    required this.candles,
    required this.interval,
    this.type = ChartType.candles,
    this.baseline,
    this.overlayBuilder,
    this.interactionOverlayBuilder,
    this.onCrosshairChanged,
    this.crosshairIndex,
    this.onPainterPainted,
    this.interactive = true,
    this.showVolume = true,
    this.logScale = false,
    this.gridlines = true,
  });

  final List<Candle> candles;
  final CandleInterval interval;
  final ChartType type;
  final double? baseline;
  final Widget Function(double candleWidth, int offset)? overlayBuilder;
  final Widget Function(double candleWidth, int offset)?
  interactionOverlayBuilder;
  final ValueChanged<int?>? onCrosshairChanged;
  final int? crosshairIndex;
  @visibleForTesting
  final ValueChanged<String>? onPainterPainted;

  /// false: a static picture with no zoom, pan, crosshair or focus (the
  /// mini chart inside an AI card).
  final bool interactive;
  final bool showVolume;
  final bool logScale;
  final bool gridlines;

  @override
  State<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends State<CandleChart>
    with SingleTickerProviderStateMixin {
  double? _zoomedWidth;
  double _scaleStartWidth = 8;

  /// How many candles we are scrolled back from the newest one.
  double _offset = 0;
  late int? _crosshair = widget.crosshairIndex;
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
                onLongPressEnd: (_) {
                  setState(() => _crosshair = null);
                  widget.onCrosshairChanged?.call(null);
                },
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
  ) => ChartCanvas(
    candles: drawn,
    interval: widget.interval,
    type: widget.type,
    candleWidth: width,
    offset: _offset.round(),
    crosshair: _crosshair,
    logScale: widget.logScale,
    gridlines: widget.gridlines,
    size: Size(constraints.maxWidth, constraints.maxHeight),
    baseline: widget.baseline,
    showVolume: widget.showVolume,
    overlayBuilder: widget.overlayBuilder,
    onPainterPainted: widget.onPainterPainted,
    interactionOverlayBuilder: widget.interactionOverlayBuilder,
  );

  void _updateCrosshair(double dx, double plotWidth, double width) {
    final index = CandleGeometry.indexAt(
      dx,
      widget.candles.length,
      plotWidth,
      width,
      _offset.round(),
    );
    if (_crosshair == index) return;
    setState(() => _crosshair = index);
    widget.onCrosshairChanged?.call(index);
  }
}
