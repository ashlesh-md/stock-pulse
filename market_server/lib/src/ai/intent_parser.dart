import 'package:market_server/src/ai/ask_request.dart';
import 'package:market_server/src/ai/glossary.dart';
import 'package:market_server/src/ai/intent.dart';
import 'package:market_server/src/ai/strategy_templates.dart';
import 'package:market_server/src/models.dart';

/// Aliases every server knows; constructor aliases override them.
const defaultAliases = <String, String>{
  'nifty': 'NIFTY',
  'nifty 50': 'NIFTY',
  'nifty50': 'NIFTY',
  'ril': 'RELIANCE',
  'hdfc bank': 'HDFCBANK',
  'icici': 'ICICIBANK',
  'sbi': 'SBIN',
  'airtel': 'BHARTIARTL',
  'l and t': 'LT',
  'maruti': 'MARUTI',
};

/// Rule-based intent parser. No model, no randomness: the
/// same question and context always give the same intent.
class IntentParser {
  IntentParser(
    List<Instrument> instruments, {
    Map<String, String> aliases = const {},
  }) {
    void add(String phrase, String id) {
      final key = normalize(phrase);
      if (key.isEmpty) return;
      _phrases[key] = id;
      final words = key.split(' ').length;
      if (words > _maxWords) _maxWords = words;
    }

    // Lowest priority first, so later writes win on a clash.
    for (final i in instruments) {
      add(i.name, i.symbol);
    }
    defaultAliases.forEach(add);
    aliases.forEach(add);
    for (final i in instruments) {
      add(i.symbol, i.symbol);
    }
  }

  final _phrases = <String, String>{};
  var _maxWords = 1;

  static final _whatDoesMean = RegExp(r'^what does (.+) mean$');
  static final _movers = RegExp(r'\b(top|biggest) (movers|gainers|losers)\b');
  static final _whoMost = RegExp(r'\bwho is (up|down) most\b');
  static const _explainPrefixes = [
    'explain ',
    'what is ',
    'whats ',
    'define ',
    'meaning of ',
  ];
  static const _otherRuleWords = {
    'quote', 'price', 'how', 'hows', 'buy', 'sell', //
    'top', 'biggest', 'movers', 'gainers', 'losers',
  };
  static final _strategies = [...StrategyKind.values]
    ..sort((a, b) => b.phrase.length.compareTo(a.phrase.length));

  /// Lower case, `&` → `and`, apostrophes dropped, other punctuation (and
  /// dots that are not decimal points) → space, spaces collapsed.
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp('[\'’]'), '')
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'(?<!\d)\.|\.(?!\d)'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9. ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Intent parse(String question, AskContext? ctx) {
    final text = normalize(question);
    if (text.isEmpty) return const UnknownIntent();
    final words = text.split(' ');
    final (:ids, :strike) = _scan(words);

    // R1 explain
    final explained = _explainTerm(text);
    if (explained != null) return ExplainIntent(explained);

    // R2 payoff
    final padded = ' $text ';
    for (final kind in _strategies) {
      if (padded.contains(' ${kind.phrase} ')) {
        return PayoffIntent(
          kind,
          ids.firstOrNull ?? ctx?.underlying ?? 'NIFTY',
          strike,
        );
      }
    }

    // R3 chain
    if (words.contains('chain') ||
        words.contains('pcr') ||
        padded.contains(' max pain ')) {
      final und = ids.firstOrNull ?? ctx?.underlying;
      if (und != null) return ChainIntent(und);
    }

    // R4 compare
    if (ids.length >= 2 &&
        (words.first == 'compare' || !words.any(_otherRuleWords.contains))) {
      return CompareIntent(List.unmodifiable(ids.take(5)));
    }

    // R5 movers
    final movers = _movers.firstMatch(text);
    if (movers != null) {
      final which = movers.group(2);
      return MoversIntent(
        losers: which == 'losers',
        gainersOnly: which == 'gainers',
      );
    }
    final who = _whoMost.firstMatch(text);
    if (who != null) {
      final down = who.group(1) == 'down';
      return MoversIntent(losers: down, gainersOnly: !down);
    }

    // R6 quote
    if (ids.isNotEmpty) {
      return QuoteIntent(
        ids.first,
        tradeWords: words.contains('buy') || words.contains('sell'),
      );
    }

    // R7 fallback
    return const UnknownIntent();
  }

  String? _explainTerm(String text) {
    String? rest = _whatDoesMean.firstMatch(text)?.group(1);
    if (rest == null) {
      for (final p in _explainPrefixes) {
        if (text.startsWith(p)) {
          rest = text.substring(p.length);
          break;
        }
      }
    }
    if (rest == null) return null;
    rest = rest.replaceFirst(RegExp(r'^(a|an|the) '), '');
    return lookupTerm(rest);
  }

  /// Resolved instrument ids in question order (longest phrase first, so
  /// "hdfc bank" beats "hdfc"), and the first number outside a symbol.
  ({List<String> ids, int? strike}) _scan(List<String> words) {
    final ids = <String>[];
    int? strike;
    var i = 0;
    while (i < words.length) {
      var matched = 0;
      for (var n = _maxWords; n >= 1 && matched == 0; n--) {
        if (i + n > words.length) continue;
        final id = _phrases[words.sublist(i, i + n).join(' ')];
        if (id != null) {
          if (!ids.contains(id)) ids.add(id);
          matched = n;
        }
      }
      if (matched == 0) {
        strike ??= int.tryParse(words[i]);
        i++;
      } else {
        i += matched;
      }
    }
    return (ids: ids, strike: strike);
  }
}
