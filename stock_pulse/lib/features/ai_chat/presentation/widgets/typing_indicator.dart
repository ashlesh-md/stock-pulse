import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';

/// Three dots that rise in turn while the answer is being prepared. Static
/// dots when the platform asks for reduced motion.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.sp.textSecondary;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                offset: Offset(0, -3 * _lift(i)),
                child: Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.45 + 0.55 * _lift(i)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _lift(int dot) {
    final t = (_controller.value - dot * 0.18) % 1;
    return t < 0.4 ? math.sin(t / 0.4 * math.pi) : 0;
  }
}
