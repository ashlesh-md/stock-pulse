enum ChainColumn { oi, oiChange, ltp, iv, delta }

/// The visible [columns] of one chain side, left to right. Calls read
/// OI … LTP and puts mirror them, so both LTPs sit next to the strike.
List<ChainColumn> chainSideColumns(
  Set<ChainColumn> columns, {
  required bool call,
}) {
  final ordered = ChainColumn.values.where(columns.contains).toList();
  return call ? ordered : ordered.reversed.toList();
}
