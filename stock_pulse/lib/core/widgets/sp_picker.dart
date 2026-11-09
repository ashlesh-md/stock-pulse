import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/sp_picker_sheet.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';

Future<T?> showSpPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required String Function(T) label,
  T? selected,
  List<T> disabledValues = const [],
}) {
  final searchable = values.length > 5;
  final contentHeight =
      112.0 + values.length * 56.0 + (searchable ? 72.0 : 0.0);
  final maxHeight = math.min(
    MediaQuery.sizeOf(context).height * 0.8,
    contentHeight,
  );
  return showSpSheet<T>(
    context,
    maxHeight: maxHeight,
    maxWidth: 640,
    builder: (_) => SpPickerSheet<T>(
      title: title,
      values: values,
      label: label,
      selected: selected,
      disabledValues: disabledValues,
      searchable: searchable,
    ),
  );
}

/// Compact single-choice control. A few short choices stay in the row; larger
/// sets and long labels open the searchable picker sheet.
class SpPicker<T> extends StatelessWidget {
  const SpPicker({
    super.key,
    required this.title,
    required this.values,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.selectedLabel,
    this.disabledValues = const [],
    this.loading = false,
    this.enabled = true,
  });

  final String title;
  final List<T> values;
  final String Function(T) label;
  final String Function(T)? selectedLabel;
  final T? selected;
  final ValueChanged<T> onChanged;
  final List<T> disabledValues;
  final bool loading;
  final bool enabled;

  bool _useSegments(BuildContext context) =>
      values.length <= 4 &&
      values.every((value) => label(value).length <= 8) &&
      MediaQuery.textScalerOf(context).scale(14) <= 20;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      final loadingLabel = context.strings.common.loading;
      return Semantics(
        label: loadingLabel,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(loadingLabel),
          ],
        ),
      );
    }
    if (_useSegments(context)) {
      return Tooltip(
        message: title,
        child: SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final value in values)
              ButtonSegment<T>(
                value: value,
                label: Text(label(value), maxLines: 1),
                enabled: enabled && !disabledValues.contains(value),
              ),
          ],
          selected: selected == null ? const {} : {selected as T},
          onSelectionChanged: !enabled
              ? null
              : (selection) {
                  if (selection.isNotEmpty) onChanged(selection.first);
                },
        ),
      );
    }
    return Tooltip(
      message: title,
      child: OutlinedButton.icon(
        onPressed: !enabled
            ? null
            : () async {
                final value = await showSpPicker<T>(
                  context,
                  title: title,
                  values: values,
                  label: label,
                  selected: selected,
                  disabledValues: disabledValues,
                );
                if (value != null) onChanged(value);
              },
        icon: const Icon(AppIcons.dropDown),
        label: Text(
          selected == null ? title : (selectedLabel ?? label)(selected as T),
        ),
      ),
    );
  }
}
