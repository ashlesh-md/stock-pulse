/// Which chain and strike range to stream. No field list and no throttle:
/// IV and delta always come at most once a second, the chain throttle is a
/// fixed 250 ms.
class ChainRequest {
  const ChainRequest({
    required this.underlying,
    required this.expiry,
    required this.fromStrike,
    required this.toStrike,
  });

  final String underlying;

  /// Expiry code, e.g. `2026-11-10`.
  final String expiry;
  final int fromStrike;
  final int toStrike;

  /// Server chain id, e.g. `NIFTY:2026-11-10`.
  String get chainId => '$underlying:$expiry';

  ChainRequest copyWith({int? fromStrike, int? toStrike}) => ChainRequest(
    underlying: underlying,
    expiry: expiry,
    fromStrike: fromStrike ?? this.fromStrike,
    toStrike: toStrike ?? this.toStrike,
  );

  @override
  bool operator ==(Object other) =>
      other is ChainRequest &&
      other.underlying == underlying &&
      other.expiry == expiry &&
      other.fromStrike == fromStrike &&
      other.toStrike == toStrike;

  @override
  int get hashCode => Object.hash(underlying, expiry, fromStrike, toStrike);
}
