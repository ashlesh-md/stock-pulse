import 'dart:async';

import 'package:flutter/material.dart';

class CardVisibility extends StatefulWidget {
  const CardVisibility({super.key, required this.builder});
  final Widget Function(BuildContext, {required bool visible}) builder;
  @override
  State<CardVisibility> createState() => _CardVisibilityState();
}

class _CardVisibilityState extends State<CardVisibility> {
  ScrollPosition? _position;
  Timer? _timer;
  bool _visible = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_position != position) {
      _position?.removeListener(_schedule);
      _position = position;
      _position?.addListener(_schedule);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _schedule() => _timer ??= Timer(const Duration(milliseconds: 200), () {
    _timer = null;
    _measure();
  });
  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject();
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox ||
        !box.hasSize ||
        viewport is! RenderBox ||
        !viewport.hasSize) {
      return;
    }
    final bounds = box.localToGlobal(Offset.zero) & box.size;
    final visible = viewport.localToGlobal(Offset.zero) & viewport.size;
    final intersection = bounds.intersect(visible);
    final fraction = intersection.isEmpty || bounds.isEmpty
        ? 0
        : intersection.height / bounds.height;
    final next = fraction >= 0.6;
    if (_visible != next) setState(() => _visible = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _position?.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, visible: _visible);
}
