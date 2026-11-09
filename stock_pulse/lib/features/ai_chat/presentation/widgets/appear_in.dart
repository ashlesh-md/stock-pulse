import 'package:flutter/material.dart';

/// Grows and fades [child] in once, when it is first built with [animate].
/// Off when the platform asks for reduced motion.
class AppearIn extends StatefulWidget {
  const AppearIn({super.key, required this.animate, required this.child});
  final bool animate;
  final Widget child;
  static const duration = Duration(milliseconds: 240);
  @override
  State<AppearIn> createState() => _AppearInState();
}

class _AppearInState extends State<AppearIn>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppearIn.duration,
    value: widget.animate ? 0 : 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _curve,
    alignment: Alignment.topCenter,
    child: FadeTransition(opacity: _curve, child: widget.child),
  );
}
