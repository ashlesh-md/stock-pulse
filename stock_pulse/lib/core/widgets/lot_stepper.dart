import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// 48 dp `−` / `+` around a tabular value. Long-press repeats.
class LotStepper extends StatefulWidget {
  const LotStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 9999,
    this.unitLabel,
  });

  final int value;
  final int min;
  final int max;

  /// Null disables the stepper (inputs locked while placing).
  final ValueChanged<int>? onChanged;

  /// Spoken unit, for example `qty`; null speaks lots.
  final String? unitLabel;

  @override
  State<LotStepper> createState() => _LotStepperState();
}

class _LotStepperState extends State<LotStepper> {
  Timer? _repeat;
  late int _current = widget.value;

  @override
  void didUpdateWidget(LotStepper old) {
    super.didUpdateWidget(old);
    _current = widget.value;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  bool _can(int delta) {
    final next = _current + delta;
    return widget.onChanged != null && next >= widget.min && next <= widget.max;
  }

  void _step(int delta) {
    if (!_can(delta)) {
      _repeat?.cancel();
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    _current += delta;
    widget.onChanged!(_current);
  }

  void _startRepeat(int delta) {
    _repeat?.cancel();
    _repeat = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _step(delta),
    );
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  Widget _button(int delta, IconData icon, String label) {
    final enabled = _can(delta);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onLongPressStart: enabled ? (_) => _startRepeat(delta) : null,
        onLongPressEnd: (_) => _stopRepeat(),
        onLongPressCancel: _stopRepeat,
        child: IconButton(
          constraints: const BoxConstraints.tightFor(
            width: SpDensity.tap,
            height: SpDensity.tap,
          ),
          onPressed: enabled ? () => _step(delta) : null,
          icon: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.common;
    final unit = widget.unitLabel;
    final unitName = unit ?? strings.lotsUnit;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(-1, AppIcons.decrease, strings.decrease(unitName)),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: SpDensity.tap),
          child: Semantics(
            label: unit == null
                ? strings.lots(widget.value)
                : strings.stepperValue(widget.value, unit),
            child: ExcludeSemantics(
              child: Text(
                '${widget.value}',
                textAlign: TextAlign.center,
                style: context.spText.price.copyWith(
                  color: context.sp.textPrimary,
                ),
              ),
            ),
          ),
        ),
        _button(1, AppIcons.increase, strings.increase(unitName)),
      ],
    );
  }
}
