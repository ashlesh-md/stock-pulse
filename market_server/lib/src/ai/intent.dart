import 'package:market_server/src/ai/strategy_templates.dart';

/// What a question asks for. [name] is the `start.intent`
/// wire value.
sealed class Intent {
  const Intent();

  String get name;
}

final class ExplainIntent extends Intent {
  const ExplainIntent(this.term);

  /// A glossary key.
  final String term;

  @override
  String get name => 'explain';

  @override
  bool operator ==(Object other) =>
      other is ExplainIntent && other.term == term;

  @override
  int get hashCode => Object.hash(name, term);

  @override
  String toString() => 'ExplainIntent($term)';
}

final class PayoffIntent extends Intent {
  const PayoffIntent(this.kind, this.underlying, this.strike);

  final StrategyKind kind;
  final String underlying;

  /// The strike from the question (not snapped yet); null = ATM.
  final int? strike;

  @override
  String get name => 'payoff';

  @override
  bool operator ==(Object other) =>
      other is PayoffIntent &&
      other.kind == kind &&
      other.underlying == underlying &&
      other.strike == strike;

  @override
  int get hashCode => Object.hash(name, kind, underlying, strike);

  @override
  String toString() => 'PayoffIntent(${kind.name}, $underlying, $strike)';
}

final class ChainIntent extends Intent {
  const ChainIntent(this.underlying);

  final String underlying;

  @override
  String get name => 'chain';

  @override
  bool operator ==(Object other) =>
      other is ChainIntent && other.underlying == underlying;

  @override
  int get hashCode => Object.hash(name, underlying);

  @override
  String toString() => 'ChainIntent($underlying)';
}

final class CompareIntent extends Intent {
  const CompareIntent(this.ids);

  /// 2–5 instrument ids in question order.
  final List<String> ids;

  @override
  String get name => 'compare';

  @override
  bool operator ==(Object other) =>
      other is CompareIntent &&
      other.ids.length == ids.length &&
      Iterable<int>.generate(ids.length).every((i) => other.ids[i] == ids[i]);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(ids));

  @override
  String toString() => 'CompareIntent($ids)';
}

final class MoversIntent extends Intent {
  const MoversIntent({required this.losers, required this.gainersOnly});

  final bool losers;
  final bool gainersOnly;

  @override
  String get name => 'movers';

  @override
  bool operator ==(Object other) =>
      other is MoversIntent &&
      other.losers == losers &&
      other.gainersOnly == gainersOnly;

  @override
  int get hashCode => Object.hash(name, losers, gainersOnly);

  @override
  String toString() => 'MoversIntent(losers: $losers, gainers: $gainersOnly)';
}

final class QuoteIntent extends Intent {
  const QuoteIntent(this.id, {required this.tradeWords});

  final String id;

  /// The question said buy/sell: the answer adds "I can't place orders".
  final bool tradeWords;

  @override
  String get name => 'quote';

  @override
  bool operator ==(Object other) =>
      other is QuoteIntent && other.id == id && other.tradeWords == tradeWords;

  @override
  int get hashCode => Object.hash(name, id, tradeWords);

  @override
  String toString() => 'QuoteIntent($id, tradeWords: $tradeWords)';
}

final class UnknownIntent extends Intent {
  const UnknownIntent();

  @override
  String get name => 'unknown';

  @override
  bool operator ==(Object other) => other is UnknownIntent;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'UnknownIntent()';
}
