import 'package:market_server/src/ai/answer_plan.dart';
import 'package:market_server/src/ai/ask_request.dart';
import 'package:market_server/src/ai/cards/card_format.dart';
import 'package:market_server/src/ai/cards/option_cards.dart';
import 'package:market_server/src/ai/cards/quote_cards.dart';
import 'package:market_server/src/ai/cards/text_cards.dart';
import 'package:market_server/src/ai/glossary.dart';
import 'package:market_server/src/ai/intent.dart';
import 'package:market_server/src/ai/intent_parser.dart';
import 'package:market_server/src/ai/strategy_templates.dart';
import 'package:market_server/src/instruments.dart' show InstrumentKind;
import 'package:market_server/src/market_reads.dart';
import 'package:option_math/option_math.dart';

/// Suggested prompts: the first chips, and the fallback card's.
const starterChips = [
  'What does the NIFTY chain say?',
  'Quote RELIANCE',
  'Compare RELIANCE and HDFCBANK',
  'Payoff of a NIFTY straddle',
  'Top movers today',
  'Explain theta',
];

const fallbackMessage =
    'I can answer quotes, comparisons, chain summaries, payoffs, top movers and terms.';

/// Turns an [Intent] into cards from [MarketReads].
/// Deterministic: the same intent and reads give the same plan. A missing
/// read gives a fallback or text card, never an exception.
class AnswerBuilder {
  AnswerBuilder(this.reads, {Map<String, String> aliases = const {}})
    : _aliases = aliases;

  final MarketReads reads;
  final Map<String, String> _aliases;
  IntentParser? _parser;

  /// Parses with the instruments the market lists (built once).
  Intent parse(String question, AskContext? ctx) => (_parser ??= IntentParser(
    reads.instruments(),
    aliases: _aliases,
  )).parse(question, ctx);

  AnswerPlan build(Intent intent, String answerId, {AskContext? ctx}) {
    final b = PlanBuilder(answerId, reads.wallNow());
    return switch (intent) {
      ExplainIntent(:final term) => _explain(b, term, ctx),
      PayoffIntent() => _payoff(b, intent, ctx),
      ChainIntent(:final underlying) => _chain(b, underlying, ctx),
      CompareIntent(:final ids) => _compare(b, ids, ctx),
      MoversIntent(:final losers) => _movers(b, losers, ctx),
      QuoteIntent(:final id, :final tradeWords) => _quote(b, id, tradeWords),
      UnknownIntent() => _fallback(b, ctx),
    };
  }

  AnswerPlan _explain(PlanBuilder b, String term, AskContext? ctx) {
    final entry = glossary[term];
    if (entry == null) return _fallback(b, ctx);
    final related = [for (final r in entry.related) glossary[r]!.title];
    b.text(entry.title, entry.paragraphs, terms: entry.related);
    return b.plan(ctx ?? const AskContext(), [
      for (final t in related.take(2)) 'Explain $t',
      starterChips.first,
    ]);
  }

  AnswerPlan _payoff(PlanBuilder b, PayoffIntent intent, AskContext? ctx) {
    final und = intent.underlying;
    final chain = reads.chainSnapshot(
      und,
      expiry: _listedExpiry(und, ctx),
      around: 20,
    );
    if (chain == null) return _noOptions(b, und, ctx);
    final step = chain.strikeStep;
    final anchor = intent.strike == null
        ? chain.atm
        : snapStrike(intent.strike!, step);
    final rows = {for (final r in chain.rows) r.strike: r};
    final templates = legsFor(intent.kind, anchor, step);
    final unlisted = rows.containsKey(anchor)
        ? templates
              .where((t) => !rows.containsKey(t.strike))
              .firstOrNull
              ?.strike
        : anchor;
    if (unlisted != null) {
      b.text('Strike not listed', [
        '${formatInr(unlisted)} is not listed for ${formatExpiry(chain.expiry)}; '
            'listed ${formatInr(chain.rows.first.strike)}–'
            '${formatInr(chain.rows.last.strike)}.',
      ]);
      return b.plan(_topicOf(chain), ['$und chain', 'Explain Strike price']);
    }
    final legs = [
      for (final t in templates)
        () {
          final row = rows[t.strike]!;
          final cell = t.right == OptionRight.ce ? row.ce : row.pe;
          return CardLegJson(
            id: cell.id,
            right: t.right,
            strike: t.strike,
            side: t.side,
            lots: t.lots,
            premium: r2(cell.ltp),
            iv: cell.iv,
          );
        }(),
    ];
    final summary = payoffSummary(payoffLegsOf(legs, chain));
    final line = payoffLine(intent.kind.label, summary);
    final title =
        '${intent.kind.label} · $und ${formatExpiry(chain.expiry)} · '
        'lot ${chain.lotSize}';
    b.card(
      payoffCard(
        id: b.nextId(),
        title: title,
        chain: chain,
        legs: legs,
        summary: summary,
        fallbackText: line,
      ),
    );
    b.text('Payoff at expiry', [line]);
    return b.plan(_topicOf(chain), ['Explain Breakeven', '$und chain']);
  }

  AnswerPlan _chain(PlanBuilder b, String und, AskContext? ctx) {
    final chain = reads.chainSnapshot(und, expiry: _listedExpiry(und, ctx));
    if (chain == null) return _noOptions(b, und, ctx);
    final quote = reads.quote(und);
    if (quote != null) {
      b.card(
        quoteCard(
          id: b.nextId(),
          quote: quote,
          name: reads.instrument(und)?.name ?? und,
          phase: reads.phase(),
        ),
      );
    }
    b.card(chainCard(id: b.nextId(), chain: chain));
    b.text('What the chain shows', [
      'PCR ${chain.pcr.toStringAsFixed(2)} (puts/calls by OI). '
          'Highest call OI at ${formatInr(chain.maxCallOiStrike)}, '
          'highest put OI at ${formatInr(chain.maxPutOiStrike)}. '
          'Max pain ${formatInr(chain.maxPain)}.',
    ]);
    return b.plan(_topicOf(chain), [
      'Payoff of a $und straddle',
      'Explain PCR',
    ]);
  }

  AnswerPlan _compare(PlanBuilder b, List<String> ids, AskContext? ctx) {
    final quotes = [for (final id in ids) ?reads.quote(id)];
    if (quotes.isEmpty) return _fallback(b, ctx);
    b.card(
      tableCard(
        id: b.nextId(),
        title: 'Compare',
        asOf: b.now,
        columns: const [
          TableColumnJson('symbol', 'Symbol'),
          TableColumnJson('ltp', 'LTP', live: true, format: 'price'),
          TableColumnJson('changePct', 'Change %', live: true, format: 'pct'),
        ],
        rows: [for (final q in quotes) (id: q.id, cells: quoteRowCells(q))],
        fallbackText: movesLine(quotes),
      ),
    );
    return b.plan(ctx ?? const AskContext(), [
      'Quote ${quotes.first.id}',
      'Top movers today',
    ]);
  }

  AnswerPlan _movers(PlanBuilder b, bool losers, AskContext? ctx) {
    final quotes = reads.topMovers(5, losers: losers);
    if (quotes.isEmpty) return _fallback(b, ctx);
    b.card(
      tableCard(
        id: b.nextId(),
        title: losers ? 'Top losers today' : 'Top gainers today',
        asOf: b.now,
        columns: const [
          TableColumnJson('symbol', 'Symbol'),
          TableColumnJson('ltp', 'LTP', live: true, format: 'price'),
          TableColumnJson('changePct', 'Change %', live: true, format: 'pct'),
        ],
        rows: [for (final q in quotes) (id: q.id, cells: quoteRowCells(q))],
        fallbackText: movesLine(quotes),
      ),
    );
    return b.plan(ctx ?? const AskContext(), [
      losers ? 'Top gainers today' : 'Top losers today',
    ]);
  }

  AnswerPlan _quote(PlanBuilder b, String id, bool tradeWords) {
    final quote = reads.quote(id);
    if (quote == null) return _fallback(b, null);
    b.card(
      quoteCard(
        id: b.nextId(),
        quote: quote,
        name: reads.instrument(id)?.name ?? id,
        phase: reads.phase(),
      ),
    );
    b.card(
      chartCard(
        id: b.nextId(),
        instrumentId: id,
        prevClose: quote.prevClose,
        candles: reads.candles(id, const Duration(minutes: 5)),
        asOf: b.now,
      ),
    );
    if (tradeWords) {
      b.text('Orders', ["I can't place orders. Open the stock to trade."]);
    }
    final other = reads
        .instruments()
        .map((i) => i.symbol)
        .where((s) => s != id && reads.quote(s)?.kind == InstrumentKind.equity)
        .firstOrNull;
    return b.plan(AskContext(underlying: id), [
      if (reads.expiries(id).isNotEmpty) '$id chain',
      if (other != null) 'Compare $id and $other',
    ]);
  }

  AnswerPlan _fallback(PlanBuilder b, AskContext? ctx) {
    b.card(
      fallbackCard(
        id: b.nextId(),
        message: fallbackMessage,
        chips: starterChips,
        asOf: b.now,
      ),
    );
    return b.plan(ctx ?? const AskContext(), starterChips);
  }

  AnswerPlan _noOptions(PlanBuilder b, String und, AskContext? ctx) {
    b.text('No options', ['$und has no listed options here.']);
    return b.plan(ctx ?? const AskContext(), [
      'Quote $und',
      starterChips.first,
    ]);
  }

  /// The context expiry when it belongs to [und] and is listed; else null
  /// (nearest).
  String? _listedExpiry(String und, AskContext? ctx) {
    final e = ctx?.expiry;
    if (e == null || ctx?.underlying != und) return null;
    return reads.expiries(und).contains(e) ? e : null;
  }

  AskContext _topicOf(ChainRead c) =>
      AskContext(underlying: c.underlying, expiry: c.expiry);
}
