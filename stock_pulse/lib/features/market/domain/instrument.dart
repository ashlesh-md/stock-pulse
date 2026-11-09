import 'package:option_math/option_math.dart' show OptionRight;

/// What an instrument is. `index` cannot be an enum value name in Dart (it
/// clashes with `Enum.index`), so the index kind is [marketIndex]; its wire
/// name stays `"index"`.
enum InstrumentKind {
  marketIndex('index'),
  equity('equity'),
  option('option');

  const InstrumentKind(this.wire);

  /// JSON value.
  final String wire;

  static InstrumentKind fromWire(String value) =>
      values.firstWhere((k) => k.wire == value);
}

/// Static facts about an instrument, loaded once over REST (lot,
/// tick and band always come from here, never from constants).
class Instrument {
  const Instrument({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.sector,
    required this.tickSize,
    required this.lotSize,
    this.kind = InstrumentKind.equity,
    this.bandLow,
    this.bandHigh,
    this.strikeStep,
    this.underlying,
    this.expiry,
    this.strike,
    this.right,
  });

  factory Instrument.fromJson(Map<String, Object?> json) => Instrument(
    symbol: (json['id'] ?? json['symbol'])! as String,
    name: json['name']! as String,
    exchange: json['exchange'] as String? ?? 'NSE',
    sector: json['sector'] as String? ?? '',
    tickSize: (json['tickSize']! as num).toDouble(),
    lotSize: json['lotSize']! as int,
    kind: switch (json['kind']) {
      final String k => InstrumentKind.fromWire(k),
      _ => InstrumentKind.equity,
    },
    bandLow: (json['bandLow'] as num?)?.toDouble(),
    bandHigh: (json['bandHigh'] as num?)?.toDouble(),
    strikeStep: json['strikeStep'] as int?,
    underlying: json['underlying'] as String?,
    expiry: json['expiry'] as String?,
    strike: json['strike'] as int?,
    right: switch (json['right']) {
      final String r => OptionRight.values.byName(r.toLowerCase()),
      _ => null,
    },
  );

  final String symbol;
  final String name;
  final String exchange;
  final String sector;

  /// Smallest allowed price step (₹0.05 on NSE for most stocks).
  final double tickSize;
  final int lotSize;
  final InstrumentKind kind;

  /// Today's price band; null when the server sends none.
  final double? bandLow;
  final double? bandHigh;

  /// Underlyings with a chain only.
  final int? strikeStep;

  /// Options only.
  final String? underlying;
  final String? expiry;
  final int? strike;
  final OptionRight? right;

  /// The protocol name for [symbol].
  String get id => symbol;

  @override
  bool operator ==(Object other) =>
      other is Instrument && other.symbol == symbol;

  @override
  int get hashCode => symbol.hashCode;
}
