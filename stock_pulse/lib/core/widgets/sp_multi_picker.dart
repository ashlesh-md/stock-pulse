import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';

/// Searchable multi-select picker. Selection is committed only by Done.
class SpMultiPicker<T> extends StatelessWidget {
  const SpMultiPicker({
    super.key,
    required this.title,
    required this.values,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.disabledValues = const [],
    this.description,
  });

  final String title;
  final List<T> values;
  final String Function(T) label;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final List<T> disabledValues;
  final String? Function(T)? description;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () async {
      final next = await showSpSheet<Set<T>>(
        context,
        maxHeight: MediaQuery.sizeOf(context).height * .8,
        maxWidth: 640,
        builder: (_) => _MultiPickerSheet<T>(
          title: title,
          values: values,
          label: label,
          selected: selected,
          disabledValues: disabledValues,
          description: description,
        ),
      );
      if (next != null) onChanged(next);
    },
    icon: const Icon(AppIcons.options),
    label: Text(title),
  );
}

class _MultiPickerSheet<T> extends StatefulWidget {
  const _MultiPickerSheet({
    required this.title,
    required this.values,
    required this.label,
    required this.selected,
    required this.disabledValues,
    required this.description,
  });

  final String title;
  final List<T> values;
  final String Function(T) label;
  final Set<T> selected;
  final List<T> disabledValues;
  final String? Function(T)? description;

  @override
  State<_MultiPickerSheet<T>> createState() => _MultiPickerSheetState<T>();
}

class _MultiPickerSheetState<T> extends State<_MultiPickerSheet<T>> {
  late final Set<T> _selected = {...widget.selected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = widget.values
        .where((value) => widget.label(value).toLowerCase().contains(_query))
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(labelText: widget.title),
              onChanged: (query) =>
                  setState(() => _query = query.trim().toLowerCase()),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final value = visible[index];
                final disabled = widget.disabledValues.contains(value);
                return CheckboxListTile(
                  value: _selected.contains(value),
                  title: Text(widget.label(value)),
                  subtitle: widget.description == null
                      ? null
                      : Text(widget.description!(value) ?? ''),
                  enabled: !disabled,
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: disabled
                      ? null
                      : (checked) => setState(() {
                          if (checked ?? false) {
                            _selected.add(value);
                          } else {
                            _selected.remove(value);
                          }
                        }),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    Navigator.pop(context, Set<T>.unmodifiable(_selected)),
                child: Text(context.strings.common.done),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
