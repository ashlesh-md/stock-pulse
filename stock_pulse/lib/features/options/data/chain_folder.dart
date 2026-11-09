import 'package:stock_pulse/core/network/domain/socket_messages.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';

ChainView foldChain(Map<String, Object?> json, [ChainView? previous]) {
  final rows = json['rows'] as List? ?? const [];
  final folded = <int, ChainRow>{...?previous?.rows};
  OptionCell? cell(Object? value) {
    if (value is! Map<String, Object?>) return null;
    return OptionCell(
      contractId: value['contractId']! as String,
      ltp: (value['ltp']! as num).toDouble(),
      change: (value['change']! as num).toDouble(),
      oi: value['oi']! as int,
      oiChange: value['oiChange']! as int,
      iv: (value['iv'] as num?)?.toDouble(),
      delta: (value['delta'] as num?)?.toDouble(),
    );
  }

  for (final raw in rows) {
    final row = raw as Map<String, Object?>;
    final strike = row['strike']! as int;
    final candidate = ChainRow(
      strike: strike,
      ce: cell(row['ce']),
      pe: cell(row['pe']),
    );
    if (folded[strike] != candidate) folded[strike] = candidate;
  }
  return ChainView(
    chainId: json['chainId'] as String? ?? previous!.chainId,
    seq: json['seq'] as int? ?? previous?.seq ?? 0,
    asOf: DateTime.fromMillisecondsSinceEpoch(
      json['asOf']! as int,
      isUtc: true,
    ),
    spot: (json['spot'] as num?)?.toDouble() ?? previous!.spot,
    atm: json['atm'] as int? ?? previous!.atm,
    status: ChainStatus.values.byName(
      json['status'] as String? ?? previous?.status.name ?? 'open',
    ),
    strikes: json['strikes'] is List
        ? (json['strikes']! as List).cast<int>()
        : previous?.strikes ?? folded.keys.toList(),
    rows: Map.unmodifiable(folded),
  );
}
