import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';

class SpPickerSheet<T> extends StatefulWidget {
  const SpPickerSheet({
    super.key,
    required this.title,
    required this.values,
    required this.label,
    this.searchable = false,
    this.selected,
    this.disabledValues = const [],
  });
  final String title;
  final List<T> values;
  final String Function(T) label;
  final bool searchable;
  final T? selected;
  final List<T> disabledValues;
  @override
  State<SpPickerSheet<T>> createState() => _SpPickerSheetState<T>();
}

class _SpPickerSheetState<T> extends State<SpPickerSheet<T>> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final values = widget.values
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
          if (widget.searchable)
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
              itemCount: values.length,
              itemBuilder: (context, index) {
                final value = values[index];
                return ListTile(
                  minVerticalPadding: 12,
                  title: Text(widget.label(value)),
                  selected: value == widget.selected,
                  trailing: value == widget.selected
                      ? const Icon(AppIcons.success)
                      : null,
                  enabled: !widget.disabledValues.contains(value),
                  onTap: widget.disabledValues.contains(value)
                      ? null
                      : () => Navigator.pop(context, value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
