import 'package:flutter/material.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// A table card's columns and rows, sized to the card: columns share the
/// width, so nothing scrolls sideways or gets clipped. A row with an `id`
/// opens it through [onOpenRow].
class AiTableView extends StatelessWidget {
  const AiTableView({super.key, required this.body, required this.onOpenRow});

  final Map<String, Object?> body;
  final ValueChanged<String> onOpenRow;

  @override
  Widget build(BuildContext context) {
    final columns = (body['columns'] as List<Object?>? ?? const [])
        .cast<Map<String, Object?>>();
    final rows = (body['rows'] as List<Object?>? ?? const [])
        .cast<Map<String, Object?>>();
    if (columns.isEmpty) return const SizedBox.shrink();
    final sp = context.sp;
    final header = context.spText.caption.copyWith(color: sp.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _line(
          columns,
          (column) => Text(column['label'].toString(), style: header),
        ),
        Divider(height: 1, color: sp.outline),
        for (final row in rows) _row(context, columns, row),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    List<Map<String, Object?>> columns,
    Map<String, Object?> row,
  ) {
    final cells = row['cells'] as Map<String, Object?>? ?? const {};
    final line = _line(
      columns,
      (column) => _cell(context, column['format'], cells[column['key']]),
    );
    return switch (row['id']) {
      final String id => InkWell(onTap: () => onOpenRow(id), child: line),
      _ => line,
    };
  }

  Widget _line(
    List<Map<String, Object?>> columns,
    Widget Function(Map<String, Object?> column) cell,
  ) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: SpDensity.tap),
    child: Row(
      children: [
        for (final (i, column) in columns.indexed)
          Expanded(
            flex: i == 0 ? 3 : 2,
            child: Align(
              alignment: i == 0 ? Alignment.centerLeft : Alignment.centerRight,
              child: FittedBox(fit: BoxFit.scaleDown, child: cell(column)),
            ),
          ),
      ],
    ),
  );

  Widget _cell(BuildContext context, Object? format, Object? value) {
    final sp = context.sp;
    return switch ((format, value)) {
      ('price', final num v) => Text(Fmt.price(v.toDouble())),
      ('pct', final num v) => Text(
        Fmt.percent(v.toDouble()),
        style: TextStyle(
          color: v > 0
              ? sp.up
              : v < 0
              ? sp.down
              : sp.textSecondary,
        ),
      ),
      _ => Text(value?.toString() ?? ''),
    };
  }
}
