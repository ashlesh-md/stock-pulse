# 06 · LLD: AI chat, live cards, strategy builder and payoff (dev-ai)

Owner: dev-ai · Status: **v2.0** (R-3, CR-1 + CR-2 structure rules) · Binding: HLD §10.2 v2.0 (C7) · Inputs: `02-prd.md` v1.1, `03-ux-spec.md` §3.8 and §7, `03b-design-system.md` 5.10 and 5.11,
`04-trd.md`, `05-hld.md` §6, §8 and §10, ADR-0004, ADR-0006 and ADR-0007, `team/proposals/ai-dev-ai.md`.
Covers (HLD §10.1): the server `ai/` module and NDJSON, `ApiClient.postLines`, `AiRepository`, the chat controller and cards,
`LiveWhenVisible`, the strategy builder, `PayoffChart`, `option_math/payoff.dart` and `openStrategyBuilder`.
**v2.0 changes (R-3; HLD v2.0 C7, ADR-0009/0010/0014/0015, CR-2 structure rules 1–5):**
- Layers: `features/<f>/{domain,data,application,presentation/{screens,widgets},di}`. Repository providers in
  `di/<f>_data_providers.dart`, controller providers in `di/<f>_providers.dart`, never in a controller file (CR-2 #1).
- Strategy: `StrategyDraftRepository` is gone. `StrategyDraftController` (`application/strategy_draft_controller.dart`,
  `Notifier<StrategyDraft>`) + `StrategyDraft` (`application/strategy_draft_state.dart`: `legs` = the draft,
  `scratch` = optional legs from the ticket or an AI card, `shownLegs`, `maxLegs = 4`) + `enum AddLegResult`.
  `strategyDraftControllerProvider` (keep-alive) is in `di/strategy_providers.dart`. `addLeg`/`clear` unchanged and always edit the
  draft; `load(StrategyArgs)`: legs → scratch (≤ 4, the draft is kept, W10); empty → show the draft. `update`/`remove` edit
  `shownLegs`. `chainKeyOf` is a pure function in `domain/strategy_args.dart`. No `watch()` stream: widgets `select` the state.
- Routes (CR-2 #2/#4): no `strategy_routes.dart`. dev-perf's `lib/app/router/` owns `StrategyRoute({StrategyArgs args})`
  (`/strategy`, name `ScreenId.strategy`, root navigator; navigation calls `load(args)` then pushes; args are not in the URL,
  so a link opens the draft) and `AiChatRoute()` (`/ai`, shell branch 2). `StrategyBuilderScreen` is
  `presentation/screens/strategy_builder_screen.dart` and takes no args.
- AI chat data: `AiRepository` interface (`domain/ai_repository.dart`, `Stream<AiEvent> ask(question, {AskTopic? topic})`;
  failures arrive as a final `AnswerFailed`, never as a stream error), sealed `AiEvent` (`domain/ai_event.dart`:
  `AnswerStarted`, `TextDelta`, `AnswerDone`, `AnswerFailed(AppError, retryable)`; `CardAdded` + `AiCard` come in S-22),
  `AskTopic` (`domain/ask_topic.dart`). `LiveAiRepository({required LinePoster postLines, newRequestId})` in `data/`
  takes the line source as a function (DI passes `apiClient.postLines`), so it is tested without HTTP. It uses a
  `StreamController`, not `async*`: a generator parked in `await for` sees a cancel only at its next `yield`, so Stop
  would not abort a silent request. `aiRepositoryProvider` is in `di/ai_chat_data_providers.dart`.
- `postLines` moved to `core/network/data/api_client_lines.dart` (still a stub until S-22).
- Server files ≤ 300 lines: `card_json.dart` → `ai/cards/{card_format,card_envelope,text_cards,quote_cards,option_cards}.dart`;
  `answer_builder.dart` → + `answer_plan.dart` (`CardDraft`, `AnswerPlan`, `PlanBuilder`); `answer_builder_test.dart` →
  + `answer_builder_payoff_chain_test.dart`. Coverage 100 % for strategy, ai_chat, `payoff.dart`, server `ai/`.
- §3.3, §4 and §7 below keep their v1.1 text where this list does not replace it.

**v1.1 changes (architect review A1–A6, decisions D5, D6, D10, D11, D12):**
- A1/D5: `addLeg(contractId, side, double premium)` → `added | full | otherChain`. `otherChain` changes nothing; the caller's snack action
  calls `clear()` then `addLeg`. The interim "clears the draft" and "premium 0" rules are removed (§0, §7).
- A2: `MarketRepository.getInstrument(id)` (`Future<Result<Instrument>>`) replaces `instrument(id)` (§7).
- A3/D12: the server uses the binding `MarketReads` (`wallNow/marketNow/phase`, `List<Instrument>`, `List<Candle>`, `ChainRead.strikeStep`,
  `expiries`, `instrument(idOrAlias)`). My assumed `InstrumentInfo`/`CandleRead`/`clock()` are dropped (§0, §1).
- A4/D10: `AlertArgs(condition: null)` replaces `direction` (§0, §5).
- A5: `openStrategyBuilder` pushes with `RouteSettings(name: ScreenId.strategy.name)` (§7).
- A6/D11: `postLines` is `extension ApiClientLines` in `core/network/api_client_lines.dart` over `ApiClient.send` (§0, §3.1).
- D6 (Q2 answered): `OptionCell.iv` is always populated at ≤ 1 Hz, so the today line has no open dependency (§7, §10).

Rules: manual Riverpod 3 providers; hand-written immutable classes (`==`, `hashCode`, `copyWith`, `fromJson`/`toJson`);
no codegen; one controller per screen; no real LLM. Nothing in this design can place an order.

## 0. Shared interfaces used (cited verbatim from HLD §10.2)

```dart
Future<http.StreamedResponse> ApiClient.send(http.BaseRequest req);      // v1.1: adds auth header (dev-realtime)
extension ApiClientLines on ApiClient { Stream<Map<String, Object?>> postLines(String path, Object body); } // dev-ai, core/network/api_client_lines.dart
Future<Result<Instrument>> MarketRepository.getInstrument(String id);                 // v1.1 (404 → "Contract data unavailable")
final liveQuoteProvider = StreamProvider.autoDispose.family<Quote, ({String id, int throttleMs})>(...);
Freshness freshnessOf({required DateTime? asOf, required bool fromCache, required DateTime serverNow,
  required bool socketLive, required MarketPhase phase});
final freshnessTickProvider = StreamProvider.autoDispose<DateTime>(...); // serverNow every 250 ms
final networkStatusProvider = StreamProvider<NetworkStatus>(...);
final marketClockProvider = StreamProvider<MarketClockState>(...);
ChainFeed ChainRepository.watchChain(ChainRequest req);               // cancel = cancel the views subscription
enum ScreenId { watchlist, options, ai, portfolio, more, stockDetail, strategy, alerts }
final screenVisibleProvider = Provider.family<bool, ScreenId>(...);
abstract final class PerfMarks { static void mark(String name, {int? seq}); }
enum OrderSource { manual, chain, position, alert, ai }
class OrderTicketArgs { String instrumentId; OrderSide side; int? lots; ProductType? product; double? limitPrice; OrderSource source; }
class AlertArgs { String instrumentId; AlertCondition? condition; double? price; OrderSource source; }   // v1.1 (D10)
class ChainArgs { String underlying; String? expiry; int? strike; OptionRight? right; }
class StrategyArgs { List<StrategyLeg> legs; }   class StrategyLeg { String contractId; OrderSide side; int lots; double premium; }
Future<void> openOrderTicket(BuildContext context, OrderTicketArgs args);   // shows risk notice first for F&O
Future<void> openChain(BuildContext context, ChainArgs args);              // switches to Options tab
Future<void> openAlertCreate(BuildContext context, AlertArgs args);
Future<void> openStock(BuildContext context, String instrumentId);
Future<void> openStrategyBuilder(BuildContext context, StrategyArgs args);
enum AddLegResult { added, full, otherChain }
AddLegResult StrategyDraftRepository.addLeg(String contractId, OrderSide side, double premium);  // v1.1: otherChain changes nothing
double bsPrice({required OptionRight right, required double spot, required double strike,
  required double years, required double iv, double rate = 0.065});
double yearsToExpiry(DateTime marketNow, DateTime expiryAt);
double payoffAtExpiry(List<PayoffLeg> legs, double spot);
PayoffSummary payoffSummary(List<PayoffLeg> legs);   // exact kinks: maxProfit?, maxLoss? (null = unlimited), breakevens, netPremium
double valueToday(List<PayoffLeg> legs, double spot, DateTime marketNow);
// market_server/lib/src/market_reads.dart (dev-realtime; consumer dev-ai's ai/) — v1.1 (D12)
abstract interface class MarketReads { DateTime wallNow(); DateTime marketNow(); MarketPhase phase();
  Instrument? instrument(String idOrAlias); List<Instrument> instruments(); QuoteRead? quote(String id);
  ChainRead? chainSnapshot(String underlying, {String? expiry, int around = 2}); List<String> expiries(String underlying);
  List<QuoteRead> topMovers(int n, {bool losers = false}); List<Candle> candles(String id, Duration interval, {int limit = 75}); }
// ChainRead { underlying, expiry, expiryAt, asOf, spot, pcr, atm, strikeStep, lotSize, maxPain, maxCallOiStrike, maxPutOiStrike, rows }
// QuoteRead { id, kind, ltp, change, changePct, prevClose, asOf }  ChainRowRead { strike, ce, pe }  ChainCellRead { id, ltp, oi, iv }
```
**Open points:** none. Q1 → D5, Q2 → D6, Q3 → D12 (README §2).

## 1. Server: `market_server/lib/src/ai/`

| File | Contents |
|---|---|
| `ask_request.dart` | `AskRequest {String question; String requestId; AskContext? context}`, `AskContext {String? underlying; String? expiry}`; `fromJson` validates: question is a trimmed string of 1–200 chars, requestId 1–64 chars |
| `intent.dart` | sealed `Intent`: `ExplainIntent(String term)`, `PayoffIntent(StrategyKind kind, String underlying, int? strike)`, `ChainIntent(String underlying)`, `CompareIntent(List<String> ids)`, `MoversIntent(bool losers, bool gainersOnly)`, `QuoteIntent(String id, bool tradeWords)`, `UnknownIntent()`; `String get name` (`explain`, `payoff`, …) |
| `intent_parser.dart` | `IntentParser(List<Instrument> instruments, {Map<String, String> aliases})` (from `reads.instruments()`) · `Intent parse(String question, AskContext? ctx)` |
| `glossary.dart` | `const glossary = <String, GlossaryEntry>{…}`; `GlossaryEntry {String title; List<String> paragraphs; List<String> related; List<String> synonyms}` (≈ 20 terms) |
| `strategy_templates.dart` | `enum StrategyKind`; `List<LegTemplate> legsFor(StrategyKind, int anchorStrike, int strikeStep)`; `LegTemplate {OptionRight right; int strikeOffsetSteps; LegSide side; int lots}` |
| `answer_builder.dart` | `AnswerBuilder(MarketReads reads)` · `AnswerPlan build(Intent intent, String answerId)`; `AnswerPlan {List<CardDraft> cards; AskContext topic; List<String> chips}`; `CardDraft {Map<String, Object?> card; List<String> textChunks}` |
| `card_json.dart` | Pure builders, one per type: `quoteCard`, `chartCard`, `chainCard`, `payoffCard`, `tableCard`, `textCard`, `fallbackCard` → `Map<String, Object?>` (schemas in §2) |
| `answer_stream.dart` | `AnswerStream(AnswerBuilder, MarketClock, {Random seedFor(String q)})` (`MarketClock` only for `delay`; times come from `MarketReads`) · `Stream<Map<String, Object?>> run(AskRequest req, {int? debugErrorAfterCard})` (`async*`) · `int get active` |
| `ndjson.dart` | `Stream<List<int>> encodeNdjson(Stream<Map<String, Object?>> events)`: `utf8.encode(jsonEncode(e) + '\n')` per event |
| `ai_api.dart` | `void mountAiApi(Router r, AnswerStream s, {required bool debug})` |

**Dependency on dev-realtime:** the binding `MarketReads` (HLD §10.2 v1.1, realtime.md §3.8), cited in §0. Use in this module:
`instruments()` feeds the parser; `instrument(idOrAlias)` is the last resolution step; `quote(id)`/`QuoteRead` → quote and table cards;
`chainSnapshot(und, expiry: null, around: 2)` → chain card (nearest expiry) and payoff anchor (`atm`, `strikeStep`, `lotSize`, `expiryAt`,
per-cell `iv`); `expiries(und)` validates an expiry in `ctx`; `topMovers(5, losers: …)`; `candles(id, Duration(minutes: 5))` (`List<Candle>`) →
chart card; `wallNow()` stamps `start.serverTime` and any card without its own `asOf`; `phase()` → quote card phase.

### 1.1 Intent rules (input lower-cased, `&` → `and`, punctuation other than `&` and `.` stripped, spaces collapsed; first rule that matches wins)

| # | Rule | Matches when | Examples → result |
|---|---|---|---|
| R1 | explain | starts with `explain`, `what is`, `whats`, `what does … mean`, `define`, `meaning of`, and the rest (or a synonym) is a glossary key | "explain theta" → `ExplainIntent(theta)` · "what is implied volatility" → `ExplainIntent(iv)` · "what is reliance" → falls through to R6 |
| R2 | payoff | contains a strategy phrase (`straddle`, `short straddle`, `strangle`, `long/short call/put`, `bull call spread`, `bear put spread`, `iron condor`); `payoff`/`p&l`/`pnl` are optional | "payoff of a nifty straddle" → `PayoffIntent(straddle, NIFTY, null)` · "bull call spread nifty 24500" → strike 24500 · "iron condor" + ctx NIFTY → NIFTY |
| R3 | chain | `<und> chain`, `option chain [of] <und>`, `what does the <und> chain say`, `pcr`/`max pain [of] <und>`, where `<und>` has options | "what does the nifty chain say?" → `ChainIntent(NIFTY)` · "pcr reliance" → RELIANCE · "chain" + ctx → ctx underlying |
| R4 | compare | `compare A (and|vs|with|,) B …`, or 2–5 resolved symbols with no other rule word | "compare reliance and hdfc bank" → `CompareIntent([RELIANCE, HDFCBANK])` · "tcs vs infy vs wipro" → 3 ids · 6+ symbols → first 5 |
| R5 | movers | `top|biggest (movers|gainers|losers)`, `who is (up|down) most` | "top movers today" → `MoversIntent(false, false)` · "top losers" → losers |
| R6 | quote | `quote|price of|how is|hows <sym>`, a lone symbol, or `buy|sell <sym>` (`tradeWords: true`) | "quote reliance" → `QuoteIntent(RELIANCE)` · "tcs" → TCS · "buy reliance" → quote + text "I can't place orders. Open the stock to trade." |
| R7 | fallback | anything else, or a symbol that cannot be resolved | "asdf" → `UnknownIntent` (fallback card + the 6 starter chips) |

- **Symbol resolution:** exact symbol, then aliases (`nifty`/`nifty 50` → NIFTY, `hdfc bank` → HDFCBANK, `ril` → RELIANCE, …),
  then the instrument's display name. Longest phrase first, so "hdfc bank" wins over "hdfc". If no symbol is found, R2 and R3 use
  `ctx.underlying`, and finally NIFTY for R2.
- **Strategy legs** are taken relative to the ATM, or to the strike given in the question snapped to `strikeStep`:
  long/short call/put = 1 leg; straddle = CE + PE at the anchor; strangle = CE +2 steps, PE −2; bull call = buy CE anchor,
  sell CE +2; bear put = buy PE anchor, sell PE −2; iron condor = sell PE −2, buy PE −4, sell CE +2, buy CE +4. All legs are
  1 lot on the nearest expiry. If a strike is outside the 41 listed strikes, the answer is a text card: "24,000 is not listed for 11 Nov; listed 23,600–25,600".
- **Determinism:** the same question with the same reads gives the same cards. Randomness is used only for delays, seeded from the question's hash.

### 1.2 Answer plans (≤ 4 cards, ≤ 8 KB encoded; checked by test)

| Intent | Cards in order | Text template (descriptive, never advice) | Done chips |
|---|---|---|---|
| explain | text | glossary paragraphs + "Related: …" (`terms` = related) | "Explain <related>" ×2, "What does the NIFTY chain say?" |
| payoff | payoff, text | "<Strategy>: max loss ₹X, max profit ₹Y / Unlimited, breakevens …" (from `payoffSummary`) | "Explain breakeven", "<und> chain" |
| chain | quote (underlying), chain, text | "PCR 0.92 (puts/calls by OI). Highest call OI at 24,700, highest put OI at 24,300. Max pain 24,500." | "Payoff of a <und> straddle", "Explain PCR" |
| compare | table (LTP live, change %, day range), text | one line per symbol: "RELIANCE +1.2% · HDFCBANK −0.4%" | "Quote <first>", "Top movers today" |
| movers | table (top 5) | none | "Top losers today" / "Top gainers today" |
| quote | quote, chart (5m, today) | only when `tradeWords` | "<sym> chain" (if it has options), "Compare <sym> and …" |
| fallback | fallback | "I can answer quotes, comparisons, chain summaries, payoffs, top movers and terms." | 6 starter chips (UX §7) |

Text templates are checked by a forbidden-phrase test ("you should", "recommend", "buy now", "sell now", "guaranteed"). The payoff
card's `summary` comes from `option_math` `payoffSummary` on the same legs, so it matches the client builder (ADR-0007).

### 1.3 Stream, delays, cancellation, faults

- `AnswerStream.run` is an `async*` generator. It does `active++` before `start` and `active--` in a `finally` (which also runs when the subscription is
  cancelled). Order: `clock.delay(think)` (300–700 ms) → `start` → for each card: `card`, then its text chunks as `delta` events
  (3–6 words, `clock.delay(40 ms)` each) → `clock.delay(150 ms)` → … → `done`. All waits go through `MarketClock.delay` (FR-120), so tests wait 0 ms.
- Text cards are sent with empty `paragraphs`, and the text arrives only as deltas. Other cards are complete in their `card` event.
- Errors: an exception in `build` before the first card produces `error` `{code: "internal", retryable: true}`. An exception after the first card produces the same event, so the
  cards already sent are kept. A missing market read gives a fallback card, not an error.
- `mountAiApi`: `POST /api/v1/ai/ask` (the auth middleware already applies). A bad body returns a JSON `400 invalid_question` (not a stream). Success:
  `Response.ok(encodeNdjson(stream.run(req)), headers: {content-type: application/x-ndjson; charset=utf-8, cache-control: no-store},
  context: {'shelf.io.buffer_output': false})`.
- **Cancellation:** when the client aborts, shelf_io cancels the body subscription. The generator stops at its next `yield`/`delay`, `finally` runs
  and `active` drops. The counter is exposed as `activeAiAnswers` in `GET /debug/subscriptions` (FR-124).
- **Fault hook (debug only):** the request header `X-Debug-Fault: error_after_card=N` makes the generator emit `error`
  `{code: "debug_fault", retryable: true}` after card N. It is ignored unless the server runs with `--debug`. The FR-122 `faults` middleware covers status codes and delays.

## 2. Wire schemas (NDJSON, one object per `\n` line, UTF-8, times in epoch ms UTC, prices as numbers to 2 dp)

| Event | Fields |
|---|---|
| `start` | `{"e":"start","answerId":str,"intent":str,"serverTime":int}` |
| `card` | `{"e":"card","card":Card}` |
| `delta` | `{"e":"delta","cardId":str,"text":str}`: appends to the last paragraph; `"\n\n"` starts a new paragraph |
| `done` | `{"e":"done","cards":int,"topic":{"underlying"?,"expiry"?},"chips":[str]}` |
| `error` | `{"e":"error","code":str,"message":str,"retryable":bool}` |

**Card envelope:** `{"id":"a7.c1","type":str,"v":1,"title":str,"asOf":int|null,"instruments":[id],"fallbackText":str,
"actions":[{"kind":str,"label":str,"args":{…}}],"body":{…}}`. `fallbackText` is required (≤ 300 chars) and is what an
`UnknownCard` shows.

| `type` | `body` | Default actions |
|---|---|---|
| `text` | `{"paragraphs":[str],"terms":[str]}`; `**bold**` is the only markup | `explain` per term (as tappable terms) |
| `quote` | `{"id","symbol","name","ltp","change","changePct","prevClose","phase":"open|preOpen|closed"}` | `open_stock`, `set_alert` |
| `chart` | `{"id","interval":"5m","prevClose","points":[[tMs,close]]}` (≤ 75) | `open_chart` |
| `chain` | `{"underlying","expiry","expiryAt","spot","atm","lotSize","pcr","maxPain","maxCallOiStrike","maxPutOiStrike","rows":[{"strike","ce":{"id","ltp","oi"},"pe":{"id","ltp","oi"}}]}` (5 rows, ATM ± 2) | `open_chain` {underlying, expiry, strike: atm}, `trade` {instrumentId: ATM CE id, side: buy, lots: 1} |
| `payoff` | `{"underlying","expiry","expiryAt","spot","lotSize","legs":[{"id","right":"CE|PE","strike","side":"buy|sell","lots","premium","iv"}],"summary":{"maxProfit":num|null,"maxLoss":num|null,"breakevens":[num],"netPremium":num}}` | `view_payoff` {legs}, `trade` {first leg} |
| `table` | `{"columns":[{"key","label","live":bool,"format":"price|pct|text"}],"rows":[{"id","cells":{key:value}}]}` (≤ 5) | row tap = `open_stock` {instrumentId} |
| `fallback` | `{"message":str,"chips":[str]}` | — |

**Action args (ids only, never a price):** `open_stock`/`open_chart`/`set_alert` `{instrumentId}` · `open_chain`
`{underlying, expiry?, strike?, right?}` · `trade` `{instrumentId, side, lots: 1}` · `view_payoff` `{legs:[{contractId, side, lots, premium}]}`
(a leg premium is the entry price for the preview, not an order price) · `explain` `{term}`. There is no `place_order` kind.

## 3. Client data layer

### 3.1 `extension ApiClientLines on ApiClient` (`core/network/api_client_lines.dart`, dev-ai; the `api_client.dart` file is dev-realtime's)
- Returns a single-subscription `Stream<Map<String, Object?>>` built on a `StreamController`. `onListen` creates
  `http.AbortableRequest('POST', uri, abortTrigger: _abort.future)` with the `content-type` header and `body = jsonEncode(body)`, then calls
  `ApiClient.send(req)` (v1.1), which adds the auth header. The extension touches no private `ApiClient` member.
- Non-2xx: read the whole body, then `addError(ServerFailure(status, code, message))` (the same `{error: {code, message}}` mapping as the REST calls) and close.
- 2xx: `res.stream.transform(utf8.decoder).transform(const LineSplitter())`. Blank lines are skipped. Each line goes through `jsonDecode`, must be a
  `Map`, then `add`. A bad line or a line over 64 KB gives `addError(ParseFailure())`, then close and abort.
- Timers (from the injected `Clock`-aware `Timer` factory, so `fakeAsync` works): 10 s to the first line and 15 s idle between lines give
  `addError(NetworkFailure('The answer stopped'))`, close and abort. `ClientException`/`SocketException` give `NetworkFailure`.
- `onCancel`: complete `_abort` (closes the socket) and cancel the timers. `Failure implements Exception`, so it travels as a stream error.

### 3.2 Domain (`features/ai_chat/domain/`)
- `ai_event.dart`, sealed `AiEvent`: `AnswerStarted {answerId, intent, serverTime}`, `CardAdded {AiCard card}`,
  `TextDelta {cardId, text}`, `AnswerDone {int cards, AskTopic topic, List<String> chips}`, `AnswerFailed {Failure failure, bool retryable}`.
- `ai_card.dart`: `const kAiCardVersion = 1`; sealed `AiCard` with common fields `{String id; int v; String title; DateTime? asOf;
  List<String> instruments; String fallbackText; List<AiAction> actions}`. Subclasses:
  `TextCard {List<String> paragraphs; List<String> terms; TextCard append(String delta)}` ·
  `QuoteCard {QuoteSnap snap; String name; MarketPhase phase}` · `MiniChartCard {String id; double prevClose; List<(DateTime, double)> points}` ·
  `ChainSnippetCard {underlying, expiry, DateTime expiryAt, double spot, int atm, int lotSize, double pcr, int maxPain, int maxCallOiStrike, int maxPutOiStrike, List<SnippetRow> rows}` ·
  `PayoffCard {underlying, expiry, DateTime expiryAt, double spot, int lotSize, List<CardLeg> legs, PayoffSummary summary}` ·
  `TableCard {List<TableColumn> columns; List<TableRow> rows}` · `FallbackCard {message, chips}` · `UnknownCard {String type}`.
  `QuoteSnap {String id; double ltp, change, changePct, prevClose; DateTime asOf}` is the first-paint snapshot.
- `AiCard.fromJson(Map)` uses `switch (json['type'])`. An unknown type, or `v > kAiCardVersion`, gives `UnknownCard` (FR-60). A missing envelope
  field gives `ParseFailure`. Body fields are cast strictly.
- `AiAction {AiActionKind kind; String label; AiActionArgs args}`, `enum AiActionKind {openStock, openChart, openChain, trade,
  setAlert, viewPayoff, explain}`. Unknown kinds are dropped while parsing. `AiActionArgs {String? instrumentId; OrderSide? side; int? lots;
  String? underlying; String? expiry; int? strike; OptionRight? right; List<StrategyLeg>? legs; String? term}`.
- `AskTopic {String? underlying; String? expiry}`.

### 3.3 `AiRepository` (`features/ai_chat/data/ai_repository.dart`)
`AiRepository(ApiClient api, {String Function()? newRequestId})` · `Stream<AiEvent> ask(String question, {AskTopic? topic})`.
It maps each line by `e` to an `AiEvent` and turns stream errors into `AnswerFailed(failure, retryable: true)`. An unknown `e` is ignored. `requestId` is
32 random hex characters from `Random.secure()` (no uuid dependency).
`final aiRepositoryProvider = Provider<AiRepository>((ref) => AiRepository(ref.watch(apiClientProvider)));`
**Architecture rule (TRD §4):** `features/ai_chat/**` imports no `features/orders/data`, `features/alerts/data` or `OrderRepository`.
Only `core/navigation` openers. This is enforced by an import test.

## 4. Chat controller and state (`features/ai_chat/presentation/`)

```
final aiChatControllerProvider = NotifierProvider<AiChatController, AiChatState>(AiChatController.new);  // keep-alive (FR-66: session only)
```
- `AiChatState {List<ChatTurn> turns; String? streamingTurnId; List<String> chips; AskTopic? topic}`, with `bool get isStreaming` and
  `ChatTurn? turn(String id)`. `ChatTurn {String id; String question; List<AiCard> cards; TurnStatus status; Failure? failure;
  bool retryable}`, `enum TurnStatus {thinking, streaming, done, interrupted, cancelled}`. Every list is `List.unmodifiable`, `==` is by value, and
  `ChatTurn.card(String cardId)` is the lookup that card widgets `select`.
- Commands:
  - `ask(String question)`: trims and ignores empty input. If an answer is streaming, it runs `stop()` first. It appends a `thinking` turn (`id` = local counter) and subscribes to
    `repo.ask(question, topic: state.topic)`.
  - `stop()`: cancels the subscription, flushes deltas, sets status `cancelled` and keeps the cards.
  - `retry(String turnId)`: clears that turn's cards in place and re-asks with the same question.
  - `clear()`: stops, then resets to the starter chips.
- Event handling: `AnswerStarted` → `streaming`. `CardAdded` → append. The first card of a turn schedules
  `PerfMarks.mark('ai_first_card_painted')` in a post-frame callback. `TextDelta` → buffered in `Map<String, StringBuffer>`, and one 50 ms
  timer flushes all buffered deltas in one state update (≤ 20 updates/s). `AnswerDone` → flush, `done`, `chips`, `topic`, and a
  `ai_stream_done` mark. `AnswerFailed` → flush, `interrupted` with `failure` and `retryable`. If the stream ends with no done/failed → `interrupted`.
- History cap: after `done`, keep the newest 50 turns (FR-66). `ref.onDispose`: cancel the subscription and the timer. The controller has **no** `onCancel` logic,
  so hiding the AI tab never stops an answer. Only card price providers pause (HLD §8.6).

## 5. Screen, cards, live prices

**`AiChatScreen`** (`ConsumerStatefulWidget`; owns the `ScrollController` and the composer `TextEditingController`):
- `ListView.builder(reverse: true, addAutomaticKeepAlives: false)`. Items are the turns, newest first, each a `TurnView(turnId)` keyed
  `ValueKey(turnId)`. A `TurnView` is a `UserBubble`, the `AiCardView`s, then a status row ("Thinking…", or
  "Answer interrupted · Retry" for `interrupted`, or "Stopped" for `cancelled`).
- "At bottom" means `offset ≤ 24 dp`. When a new card arrives and the list is not at the bottom, a `NewAnswerPill` shows (a local `ValueNotifier<bool>`).
  Nothing ever auto-scrolls the user away from where they are.
- The composer and chips are pinned at the bottom, with chips above the field. Send becomes Stop while `isStreaming`. Each part is a separate `select`.
- `AiCardView(turnId, cardId)` does `ref.watch(aiChatControllerProvider.select((s) => s.turn(turnId)?.card(cardId)))`, so a delta
  rebuilds one card only. It switches on the sealed type to pick the body widget, inside `AiCardShell`.
- `AiCardShell` (03b 5.10) has a header (icon, title, `as of hh:mm:ss`), a 2 dp progress rule while its turn streams, the body, action `TextButton`s, and a
  permanent footer "Simulated. Not advice." (FR-62). It is never truncated and wraps at text scale 2.0.

| Body widget | Content | Live ids |
|---|---|---|
| `TextCardBody` | `Text.rich` from paragraphs (`**bold**` → bold span); terms are `TextButton`-styled spans (≥ 48 dp hit area, via `WidgetSpan`) → `ask('Explain <term>')` | none |
| `QuoteCardBody` | symbol, name, `SpPriceCell` LTP, `ChangeChip`, phase or `StaleBadge` | quote id |
| `MiniChartCardBody` | v1 `CandleChart(type: ChartType.line, baseline: prevClose, interactive: false, showVolume: false)`, 120 dp; points are mapped to `Candle` with o = h = l = c; the last point is replaced by the live LTP | quote id |
| `ChainSnippetCardBody` | stats line (PCR, max pain, max-OI strikes); 5 rows `CE LTP · OI | STRIKE | PE LTP · OI`; ATM row highlighted | 10 contract ids + underlying |
| `PayoffCardBody` | `PayoffChart.compact` (140 dp, expiry line only, no gestures; tap = `view_payoff`) + summary chips from `summary` | none |
| `TableCardBody` | ≤ 5 rows of 48 dp; `live` columns use `LiveQuoteText`; row tap → `openStock` | row ids with live columns |
| `FallbackCardBody` | message + chips → `ask(chip)` | none |
| `UnknownCardBody` | `fallbackText` as text (FR-60) | none |

**`LiveWhenVisible`** (`features/ai_chat/presentation/live/live_when_visible.dart`, in house, ADR-0004):
`LiveWhenVisible({required Widget Function(BuildContext, bool live) builder, double minFraction = 0.5, Duration throttle = 200 ms})`,
a `ConsumerStatefulWidget`.
- In `didChangeDependencies` it attaches to `Scrollable.maybeOf(context)?.position` (a `Listenable`). Changes are throttled: at most one check per 200 ms,
  and a trailing check always runs. A post-frame check also runs after the first layout and after any size change (`SizeChangedLayoutNotifier`).
- Check: the card's `RenderBox` rect and the scrollable's viewport rect are converted to global coordinates. `visibleFraction` = overlap height / card height. Then
  `inViewport = visibleFraction ≥ minFraction`.
- `live = inViewport && ref.watch(screenVisibleProvider(ScreenId.ai))`. `setState` runs only when `live` flips.
- Budget: a 200 ms check + a frame + autoDispose + the 300 ms repository linger + the send ≈ 0.6 s < 1 s (FR-63, NFR-14).

**`LiveQuoteText` / `LiveQuoteScope`:** the card body wraps its live part in `LiveWhenVisible`. When `live` is true, a `Consumer` watches
`liveQuoteProvider((id: id, throttleMs: 1000))` for each id, plus `freshnessTickProvider`, `networkStatusProvider` and
`marketClockProvider`. It stores the newest `Quote` in the widget `State` (`_last`). When `live` is false, no provider is watched, so the
autoDispose families drop. The socket ref-count falls and the server unsubscribes. The widget then shows `_last`, or the card snapshot, with
the freshness computed once. Value used: `_last ?? snapshot`. Freshness is `freshnessOf(asOf: value.asOf, fromCache: false,
serverNow: tick, socketLive: network == live, phase)`. Stale shows dimmed with `StaleBadge` "Stale since hh:mm:ss" (§3.1, FR-63).
Two cards on one id share one server subscription (TR-11).
**Off-screen lifetime:** card elements are disposed when they scroll out (`addAutomaticKeepAlives: false`). The data stays in controller
state (≤ 50 turns × 4 cards × 8 KB ≈ 1.6 MB). Scrolling back rebuilds from state and re-subscribes, and the snapshot or `_last` shows until a frame arrives.

**Actions:** `Future<void> runAiAction(BuildContext context, WidgetRef ref, AiAction a)` (`ai_action_runner.dart`):

| kind | call |
|---|---|
| `openStock`, `openChart` | `openStock(context, args.instrumentId!)` (the stock page holds the chart) |
| `openChain` | `openChain(context, ChainArgs(underlying, expiry, strike, right))` |
| `trade` | `openOrderTicket(context, OrderTicketArgs(instrumentId, side, lots: 1, product: null, limitPrice: null, source: OrderSource.ai))` |
| `setAlert` | `openAlertCreate(context, AlertArgs(instrumentId, condition: null, price: null, source: OrderSource.ai))` |
| `viewPayoff` | `openStrategyBuilder(context, StrategyArgs(legs))` |
| `explain` | `ref.read(aiChatControllerProvider.notifier).ask('Explain ${args.term}')` |
Stale handling and the risk notice belong to the opened sheet (PRD Q7, D-6). The chat shows no stale state on its buttons.

## 6. `packages/option_math/lib/src/payoff.dart` (owner dev-ai)

- `enum LegSide {buy, sell}` (so the package does not import the app's `OrderSide`). `PayoffLeg {OptionRight right; double strike; LegSide side;
  int units; double premium; double iv; DateTime expiryAt}`, where `units = lots × lotSize` and the sign `s` is +1 for buy, −1 for sell.
  `PayoffSummary {double? maxProfit; double? maxLoss; List<double> breakevens; double netPremium; double rightSlope}`, with `==` and `toJson`/`fromJson`
  (the server writes it into the card). `OptionRight` comes from `pricing.dart`.
- `payoffAtExpiry(legs, S)` = Σ s·units·(intrinsic(right, S, K) − premium), where intrinsic CE = max(S − K, 0) and PE = max(K − S, 0).
- `payoffSummary(legs)`: throws `ArgumentError` on empty legs or more than 4 legs. Steps:
  1. Kinks `x` = {0} ∪ sorted unique strikes. `v_i = payoffAtExpiry(x_i)`.
  2. `rightSlope` = Σ s·units over CE legs.
  3. Max profit = `null` (Unlimited) if `rightSlope > 0`, else max(v). Max loss = `null` if `rightSlope < 0`, else min(v). It is reported
     as a P&L value (≤ 0; the UI shows the absolute value). It is `0` when no loss is possible.
  4. Breakevens: for consecutive kinks with `v_i·v_{i+1} < 0`, use `x_i + (0 − v_i)·(x_{i+1} − x_i)/(v_{i+1} − v_i)`. A kink with `v_i = 0` counts
     once, and only where the sign changes across it. A zero-flat segment reports both of its ends. Right tail: if `v_last ≠ 0` and `rightSlope` has the opposite sign,
     `x_last − v_last/rightSlope`. Values are rounded to 2 dp and sorted.
  5. `netPremium` = −Σ s·units·premium (negative = debit).
  The result is exact because the payoff is piecewise linear between kinks. Nothing is sampled.
- `valueToday(legs, S, marketNow)` = Σ s·units·(bsPrice(right, S, K, yearsToExpiry(marketNow, expiryAt), iv) − premium). When
  `years ≤ 0`, intrinsic is used, so it equals `payoffAtExpiry`. Time is **market time** (TR-18).

## 7. Strategy builder (`features/strategy/`)

**`StrategyDraftRepository`** (`data/`, keep-alive `Provider`): it holds a `List<StrategyLeg>` for the chain's "Add to strategy" while the builder
is closed. Methods: `AddLegResult addLeg(String contractId, OrderSide side, double premium)` (v1.1, cited), `Stream<List<StrategyLeg>> watch()`,
`List<StrategyLeg> get legs`, `void update(int i, {OrderSide? side, int? lots})`, `void remove(int i)`, `void clear()`.
- `added`: the leg is appended with the caller's premium (the chain cell's LTP), 1 lot.
- `full`: there are already 4 legs; nothing changes. The caller shows "Up to 4 legs in preview".
- `otherChain`: the contract's underlying or expiry differs from the draft's first leg; **nothing changes**. The caller (chain, dev-trading)
  shows the snack "Strategy uses NIFTY 10 Nov · Start new", whose action calls `clear()` then `addLeg` (D5). The repository never clears on its own.
- The chain key is read from the contract id (TR-25 format `NIFTY-261110-24500-CE`), so `addLeg` stays synchronous.

**`StrategyBuilderController`** (`presentation/`), `NotifierProvider.autoDispose.family<StrategyBuilderController, StrategyBuilderState, StrategyArgs>`.
- Source of legs: `args.legs.isEmpty` → draft mode (reads and writes the draft repository). Otherwise → **scratch** mode. Scratch is used from
  the ticket's "Payoff ›" (FR-70, one leg) and from the AI `view_payoff` action, and it never overwrites the user's draft.
- `StrategyBuilderState {String? underlying; String? expiry; int? lotSize; List<BuilderLeg> legs; double? spot; DateTime? spotAsOf;
  PayoffSummary? summary; PayoffGeometry? geometry; bool todayShown; String? todayHiddenReason; BuilderStatus status; Failure? failure; bool fullNotice}`.
  `BuilderLeg {StrategyLeg leg; OptionRight right; int strike; DateTime expiryAt; double? liveLtp; double? iv; Freshness freshness}`.
  `enum BuilderStatus {empty, loading, ready, error}`.
- Metadata (right, strike, expiry, lot size) comes only from instrument metadata (TR-25), through `MarketRepository.getInstrument(id)`
  (`Future<Result<Instrument>>`, v1.1), awaited in `build` with `ref.mounted` checked after each await. `Err` (404 → "Contract data unavailable")
  gives status `error` with "Couldn't price legs · Retry".
- Live data: while `screenVisibleProvider(ScreenId.strategy)` is true, one `ChainRepository.watchChain(ChainRequest(underlying, expiry,
  fromStrike: minLegStrike, toStrike: maxLegStrike))` provides spot, leg LTP and `iv`, and `asOfFor(contractId)`. It is ref-counted with the
  chain screen's subscription when the chainId is the same. `OptionCell.iv` is always populated at ≤ 1 Hz (D6), so a null `iv` only
  means "not priced yet" and hides the today line until it arrives.
- Recompute rules:
  - When the legs change (side, lots, add, remove): `summary = payoffSummary(...)` and new expiry geometry, at once.
  - When a view arrives: spot and freshness are updated, and the today line is recomputed at most once per second (`Clock`-based gate).
  - If any leg or the spot is not `live` (stale; Closed is fine), `todayShown = false` and `todayHiddenReason = "Today line needs live prices"` (UX §3.8).
- Commands: `setSide(i, side)`, `setLots(i, lots)` (1…100), `remove(i)`, `tradeLeg(i)` (the widget calls
  `openOrderTicket(context, OrderTicketArgs(instrumentId: contractId, side, lots, product: null, limitPrice: null, source: OrderSource.manual))`),
  `retry()`. A 5th leg is impossible (`full` gives the notice "Up to 4 legs in preview").
- `openStrategyBuilder(context, args)` (I own it): `rootNavigatorKey.currentState!.push(MaterialPageRoute(settings:
  RouteSettings(name: ScreenId.strategy.name), builder: (_) => StrategyBuilderScreen(args: args)))` (A5, D4). The name lets
  `VisibilityRouteObserver` drive `screenVisibleProvider(ScreenId.strategy)`. The route is opaque, so the screen below pauses (HLD §8).

**`PayoffGeometry`** (pure, built in the controller, never in `paint`): `{double xMin, xMax, yMin, yMax; Float64List expiryX, expiryY
(kinks within the range plus both ends, so the polyline is exact); Float64List? todayY (121 samples over [xMin, xMax]); List<double> breakevens;
double? spot; bool clippedTop, clippedBottom}`. Range: x from min(strikes, spot) − 6% to max(strikes, spot) + 6%. y from both curves
plus 10%, always including 0. Unlimited tails are clipped and marked with an edge arrow.

## 8. `PayoffChart` (CustomPainter plan, 03b 5.11)

- `PayoffChart({required PayoffGeometry geometry, required String semanticsSummary, bool compact = false})`, a `StatefulWidget` that owns
  `ValueNotifier<double?> _crosshairX`.
- Tree: `Semantics(label: "Payoff at expiry. Max loss 15,860. Breakevens 24,256 and 24,744")` → `SizedBox(height: compact ? 140 : 220)`
  → `Stack`:
  1. `RepaintBoundary(CustomPaint(painter: _PayoffStaticPainter(geometry, colors, labelStyle)))`. Its `shouldRepaint` is `old.geometry != geometry || colors changed`.
  2. `CustomPaint(painter: _CrosshairPainter(geometry, _crosshairX))`, which uses `super(repaint: _crosshairX)`. A drag repaints only this layer.
  3. A tooltip widget (`ValueListenableBuilder`), positioned at the top, that flips to the left or right side near the edges so it stays within 360 dp.
- Static paint order: fills (closed path from the expiry polyline to the zero line, clipped above zero with `upTint` and below zero with `downTint`) → zero line
  (1 dp `outline`) → expiry line (2 dp `textPrimary`) → today line (dashed `info`; the dash path is built once in the painter constructor with
  `PathMetric.extractPath`) → spot line (1 dp `accent`, vertical) → breakeven dots (r = 3) and labels → axis ticks (4–5, nice-number
  steps) with compact ₹ labels (`₹15.9K`, `₹1.2L`, `₹1.1Cr`) and clip arrows.
- The `TextPainter`s for labels are created and laid out once per painter instance, not on every paint. The label text scale is
  `MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3)`. The full risk text lives in the chips under the chart, at any scale (NFR-12).
- Label collision: if two breakeven labels are closer than 48 dp, the second goes below the axis. The spot label goes above the plot.
- Gestures (full size only): `onHorizontalDragStart/Update` set `_crosshairX`. `onTapUp` is the tap alternative (FR-73, UX §5). A second tap on
  the same point hides the crosshair. A move that crosses a breakeven fires `HapticFeedback.selectionClick()` (sign change of the
  P&L at the previous and current x).
- Compact mode has no gestures, no today line and no crosshair layer.

**Builder screen** (UX §3.8): app bar "Strategy · NIFTY 11 Nov · lot 65" → `PayoffChart` → `SummaryChips` ("Max profit Unlimited",
"Max loss ₹15,860": text, never colour alone) → "Breakevens 24,256 / 24,744 · Net −₹15,860" → `Legs (n/4)` → `LegRow`
(`SegmentedChoice` side, `LotStepper`, premium, `[Trade]`, `[✕]`; ≥ 48 dp) → "+ Add leg from chain" (`openChain`) → "ⓘ Preview only · each leg trades alone".
Other states: Empty "Add legs from the option chain" + Open chain. Error "Couldn't price legs · Retry". Stale: the today line is hidden and the reason is shown.

## 9. Tests (traced to FR / NFR / TR)

| # | Level | Test | Traces |
|---|---|---|---|
| P1 | unit (option_math) | long CE: maxLoss = −premium×units, maxProfit null, BE = K + premium | FR-72, TR-18 |
| P2 | unit | short CE: maxLoss null; long PE: maxProfit = (K − premium)×units at S = 0 | FR-72 |
| P3 | unit | long straddle: V shape, 2 BEs = K ± (pCE + pPE); netPremium = −(sum)×units | FR-71, FR-72 |
| P4 | unit | bull call spread and iron condor (4 legs): both bounded, BEs exact; zero-flat segment and BE at a kink not duplicated | FR-71, TR-18 |
| P5 | unit | `valueToday` at years ≤ 0 equals `payoffAtExpiry`; it equals Σ `bsPrice` at T > 0; market time used, not wall time | FR-71, TR-18 |
| P6 | unit | 0 or 5 legs → `ArgumentError` | FR-71 |
| S1 | unit (server) | table-driven `IntentParser`: ≥ 2 positives per rule R1–R7, "hdfc bank" longest match, follow-up via ctx, strike snapping, "buy reliance" → quote + tradeWords | FR-61, FR-65 |
| S2 | unit | `AnswerBuilder` with fake `MarketReads`: ≤ 4 cards, ≤ 8 KB, every card has `fallbackText` and `v`, deterministic, payoff summary == `payoffSummary` | FR-60, FR-61, TR-17 |
| S3 | unit | every action's args contain no price key and no `place_order` kind; forbidden-phrase scan of all templates | FR-64, FR-62 |
| S4 | e2e (TestServer, gated `FakeMarketClock.delay`) | with the delays held, the client receives `start` and the first `card` line before `done` is produced (buffer_output off); content-type is `application/x-ndjson` | FR-60, FR-67, TR-17 |
| S5 | e2e | abort after card 1 → `activeAiAnswers` returns to 0 and no further lines are written | FR-67, FR-124 |
| S6 | e2e | `X-Debug-Fault: error_after_card=2` → start, 2 cards, error; the header is ignored without `--debug` | FR-67 |
| S7 | e2e | 400 on a bad body, 401 without the token, gibberish → fallback card with chips | FR-65, TRD §4 |
| C1 | unit (client) | `postLines` with `MockClient.streaming`: JSON split across chunks, two lines in one chunk, CRLF, ₹ split across chunks, blank lines | FR-67 |
| C2 | unit | `postLines`: 500 → `ServerFailure`; bad line → `ParseFailure`; `fakeAsync` 15 s idle → `NetworkFailure`; cancel completes `abortTrigger` | FR-67 |
| C3 | unit | `AiCard.fromJson` per type; unknown type and v = 2 → `UnknownCard`; unknown action kind dropped | FR-60 |
| C4 | unit (ProviderContainer, fake repo) | 5 deltas within 50 ms → 1 state update; done sets chips and topic; error after card 2 → 2 cards + interrupted; end without done → interrupted | FR-60, FR-67 |
| C5 | unit | stop keeps cards and cancels the subscription; ask while streaming stops the old answer; retry replaces in place; 51st answer drops the oldest; clear | FR-66, FR-67 |
| C6 | unit | import test: `features/ai_chat/**` has no order or alert repository imports | FR-64, TRD §4 |
| W1 | widget | first card painted while the fake stream is still open; Send shows Stop | FR-60, FR-67 |
| W2 | widget | footer "Simulated. Not advice." on every card type, including `UnknownCard` | FR-62 |
| W3 | widget | card 60% in viewport → `liveQuoteProvider` has a listener; scrolled to 40% → none after 200 ms + 1 frame; `screenVisibleProvider(ai)` false → none | FR-63, NFR-14 |
| W4 | widget (fake clock) | card snapshot `asOf` 5.1 s old with no live frame → `StaleBadge`; 5.0 s → live | FR-63, NFR-7 |
| W5 | widget | "Trade this strike" → fake opener receives `OrderTicketArgs(lots: 1, limitPrice: null, source: ai)`; fake `OrderRepository.place` count 0 | FR-64 |
| W6 | widget | not at bottom: a new card shows the "New answer" pill and the offset is unchanged; at bottom, the list follows | UX §7 |
| W7 | widget | 360×800, text scale 2.0: chat with every card type + builder, `takeException` null; tap-target and contrast guidelines pass | NFR-12 |
| W8 | widget | builder: one leg from the ticket → hockey stick; straddle → V (goldens in both themes); chips show "Max loss ₹…" | FR-70, FR-71, FR-72 |
| W9 | widget | crosshair drag moves the label; tap alternative; tooltip stays inside 360 dp at the edges; `selectionClick` only on breakeven crossings; the static painter's debug paint count is unchanged during the drag | FR-73 |
| W10 | widget | stale leg → today line hidden with the reason; 5th add → "Up to 4 legs in preview"; scratch args do not change the draft | FR-71, UX §3.8 |
| U1 | unit | `addLeg`: added with the given premium; 5th → `full`; other underlying or expiry → `otherChain` and legs unchanged; `clear()` then `addLeg` → added | FR-29, FR-71, D5 |
| W11 | widget | builder pushed via `openStrategyBuilder` → `screenVisibleProvider(ScreenId.strategy)` true; push an opaque route on top → false and the chain feed is cancelled | FR-86, A5 |
| I1 | integration (TestServer) | 2 cards on RELIANCE → 1 server quote sub; scroll both off → 0 within 1 s (`/debug/subscriptions`) | FR-63, NFR-14, TR-11 |
| I2 | integration | J-4: chip "What does the NIFTY chain say?" → quote + chain + text; View payoff → builder max loss; Trade this strike → ticket "From AI chat"; 0 POSTs | FR-61, FR-64, FR-72, J-4 |
| PF | perf (dev-perf harness) | chat scroll with 2 live cards + an answer streaming; marks `ai_first_card_painted`, `ai_stream_done` | NFR-4 (method), FR-125 |

## 10. Risks
- If shelf buffering returns, streaming breaks. S4 guards this.
- The intent grammar is narrow. Chips and the fallback steer users, and S1 grows with each new phrase.
- Fast flings: the 200 ms throttle and the 300 ms linger absorb repeats, and the socket ref-count means no duplicate server subscriptions.
