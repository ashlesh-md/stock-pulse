import 'package:flutter/material.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// Open interest as a share of the largest OI in the chain; grows from the
/// strike outwards, so CE bars are right-aligned and PE bars left-aligned.
class OiBar extends StatelessWidget {
  const OiBar({
    super.key,
    required this.fraction,
    required this.color,
    required this.fromRight,
  });

  /// 0 to 1.
  final double fraction;
  final Color color;
  final bool fromRight;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Align(
      alignment: fromRight ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0, 1).toDouble(),
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(SpRadius.pill),
          ),
        ),
      ),
    ),
  );
}
