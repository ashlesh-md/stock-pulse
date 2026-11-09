import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One segment of a [SegmentedChoice].
class SpSegment<T> {
  const SpSegment(this.value, this.label, {this.enabled = true});
  final T value;
  final String label;
  final bool enabled;
}

/// Single-select segmented control on M3 `SegmentedButton`, styled
/// by the theme. Selection is shown by weight too, never colour alone; a
/// change gives a `selectionClick`.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<SpSegment<T>> segments;
  final T selected;

  /// Null disables the whole control.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: [
        for (final s in segments)
          ButtonSegment<T>(
            value: s.value,
            enabled: s.enabled,
            label: Text(
              s.label,
              style: TextStyle(
                fontWeight: s.value == selected
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
      ],
      selected: {selected},
      onSelectionChanged: onChanged == null
          ? null
          : (set) {
              if (set.isEmpty || set.first == selected) return;
              unawaited(HapticFeedback.selectionClick());
              onChanged(set.first);
            },
    );
  }
}
