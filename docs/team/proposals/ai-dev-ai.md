# Proposal: AI chat, live cards, payoff (dev-ai)

Round: propose · Inputs: PRD v1.1 (C11, D-3, D-6, §3.1, §4.7, §4.8, §10), UX §3.8 + §7, 03b 5.10 + 5.11 · No code.

## 1. Scope
- **FR:** FR-60…FR-67 (chat, intents, footer, live cards, actions, chips, history, NDJSON), FR-70…FR-73 (single-leg payoff, builder ≤ 4 legs, max P/L + breakevens, crosshair). Shares FR-29 (Add to strategy) and FR-93 (`asOf` on card prices).
- **NFR:** NFR-12 (360 dp, text scale 2.0), NFR-14 (off-screen cards unsubscribe ≤ 1 s), NFR-18 (manual Riverpod 3, no codegen, one controller per screen), NFR-7 (card prices follow §3.1).
- **Not mine:** order placement, alert creation, chain socket channel, option pricing in the engine.

## 2. Server (`market_server/lib/src/ai/`: `intent_parser.dart`, `answer_builder.dart`, `ai_api.dart`)
**Route:** `POST /api/v1/ai/ask`, body `{"question": str, "requestId": uuid, "context": {"underlying"?, "expiry"?}}` (context = last answer topic, for follow-up chips). Same auth middleware. Response `200`, `content-type: application/x-ndjson`, `cache-control: no-store`, shelf context `shelf.io.buffer_output: false` so each line flushes. Bad body → normal JSON `400` (not a stream).

**Intent grammar** (lower-cased, punctuation stripped, symbols resolved from the instrument list plus aliases such as `nifty`, `hdfc bank`; first match wins):

| # | Intent | Patterns | Examples | Cards |
|---|---|---|---|---|
| 1 | explain | `explain|what is|whats|define|meaning of <term>` | "explain theta", "what is PCR" | text |
| 2 | payoff | `payoff|p&l of <strategy> [on|for <und>] [<strike>]` | "payoff of a NIFTY straddle", "bull call spread nifty 24500" | payoff, text |
| 3 | chain | `<und> chain`, `what does the <und> chain say`, `pcr|max pain [of] <und>` | "what does the NIFTY chain say?" | quote, chain, text |
| 4 | compare | `compare A (and|vs|with) B [and C]`, or 2–5 symbols with no other verb | "RELIANCE vs HDFCBANK" | table, text |
| 5 | movers | `top|biggest (movers|gainers|losers) [today]` | "top losers today" | table |
| 6 | quote | `quote|price of|how is <sym>`, or a lone symbol | "quote RELIANCE", "tcs" | quote, chart |
| 7 | fallback | anything else | "asdf" | fallback (chips) |

Term dictionary (≈ 20): delta, gamma, theta, vega, IV, OI, PCR, max pain, ATM/ITM/OTM, lot, expiry, straddle, strangle, spread, MIS, NRML, CNC, breakeven, premium. Strategies: long/short call/put, straddle, strangle, bull call spread, bear put spread, iron condor (4 legs, the cap); strikes default to ATM (± 1–2 strikes for spreads), nearest expiry, 1 lot. Answers are **deterministic** for the same question and market state (seeded random only for latency), so tests can assert cards.

**Card JSON** (every card; `v` is the card schema version, starts at 1):
`{"id","type","v":1,"title","asOf"(ms|null),"instruments":[ids],"fallbackText","actions":[{"kind","label","args"}],"body":{…}}`
- `text`: `{"paragraphs":[str], "terms":[str]}` (`**bold**` only; terms become Explain taps). Text grows by deltas.
- `quote`: `{"symbol","ltp","change","changePct","prevClose","phase"}`.
- `chart`: `{"symbol","interval":"5m","prevClose","points":[[tMs, close]]}` (today, ≤ 75 points).
- `chain`: `{"underlying","expiry","spot","atm","lotSize","pcr","maxCallOiStrike","maxPutOiStrike","rows":[{"strike","ce":{"id","ltp","oi"},"pe":{…}}]}` (ATM ± 2 = 5 rows).
- `payoff`: `{"underlying","expiry","spot","lotSize","legs":[{"id","right":"CE|PE","strike","side","lots","premium","iv"}],"summary":{"maxProfit"(null = Unlimited),"maxLoss"(null = Unlimited),"breakevens":[num],"netPremium"}}`.
- `table`: `{"columns":[{"key","label","live":bool}],"rows":[{"symbol","cells":{key: value}}]}` (≤ 5 rows).
- `fallback`: `{"message","chips":[str]}` · `error` is never a card on the wire; it is an event (below).
- **Action kinds:** `open_stock`, `open_chart`, `open_chain`, `trade`, `set_alert`, `view_payoff`, `explain`. `args` carry ids only (`instrumentId`, `side`, `lots`, `strike`, `expiry`, `legs`); the client builds routes. There is no `place_order` kind, by design.

**NDJSON events** (one JSON object per `\n`-terminated line, UTF-8):
`{"e":"start","answerId","intent","serverTime"}` → `{"e":"card","card":{…}}` (shell; text cards arrive with empty paragraphs) → `{"e":"delta","cardId","text"}` (appends to the last paragraph; `"\n\n"` starts a new one) → `{"e":"done","cards":n}` or `{"e":"error","code","message","retryable":bool}`. At most 4 cards and 8 KB per answer. A stream that ends with no `done`/`error` is treated by the client as `interrupted`.

**Latency simulation:** "thinking" 300–700 ms before `start`, 150 ms between cards, text deltas of 3–6 words every 40 ms (whole answer ≤ 3 s). All delays go through the injectable `Clock`/delay hook (FR-120) so tests run with zero waiting. Fault hook (FR-122 style, debug only): `X-Debug-Fault: error_after_card=2` produces the FR-67 acceptance case.

**Cancellation:** the answer is an `async*` generator piped into the response body. When the client closes the request, shelf_io cancels the body subscription and the generator stops at its next `yield`/delay; no further market reads. A debug counter `activeAiAnswers` (FR-124 sub counts) proves it drops to 0.

## 3. Client (`features/ai_chat/`: data, domain, presentation)
**Reading the stream:** add `ApiClient.postLines(path, body)` returning `Stream<Map<String, Object?>>`. It sends an `http.AbortableRequest` (package:http ≥ 1.3, `abortTrigger` future) via `client.send`; non-2xx → read the body and emit the usual `ServerFailure`; 2xx → `response.stream.transform(utf8.decoder).transform(const LineSplitter())`, skip blank lines, `jsonDecode` each line. Timeouts: 10 s to first byte, 15 s idle between lines → `NetworkFailure`. Cancelling the Dart subscription completes `abortTrigger`, which closes the socket. `AiRepository.ask(question, context)` maps lines to a sealed `AiEvent` (`AnswerStarted`, `CardAdded`, `TextDelta`, `AnswerDone`, `AnswerFailed`).

**Domain:** sealed `AiCard` with `TextCard`, `QuoteCard`, `MiniChartCard`, `ChainSnippetCard`, `PayoffCard`, `TableCard`, `FallbackCard`, plus `UnknownCard` (unknown `type` or `v` > supported → rendered as text from `fallbackText`, FR-60). Hand-written `fromJson` with `switch` patterns; a malformed line ends the turn as interrupted (cards kept). `AiAction {kind, label, args}`.

**Controller and state:** `aiChatControllerProvider = NotifierProvider<AiChatController, AiChatState>` (not autoDispose: session history survives tab switches, cleared on kill, FR-66). Immutable `AiChatState {List<ChatTurn> turns (≤ 50, oldest dropped), String? streamingTurnId, List<String> chips}`; `ChatTurn {id, question, List<AiCard> cards, TurnStatus streaming|done|interrupted|cancelled, Failure? failure}`; hand-written `copyWith`, `List.unmodifiable`, value `==`. Commands: `ask`, `stop`, `retry(turnId)`, `clear`. One answer at a time: `ask` while streaming stops the old one first. Text deltas are coalesced and applied at most every 50 ms. `ref.onDispose` and `stop` cancel the subscription; error after card 2 keeps cards 1–2 and sets `interrupted` (the UI adds "Answer interrupted · Retry"). Tab hide does **not** cancel the answer (≤ 3 s, no prices), only card price streams.

**Rendering:** `ListView.builder(reverse: true)` keyed by turn/card id, `addAutomaticKeepAlives: false`; at bottom = offset ≤ 24 dp, else "↓ New answer" pill. Each card widget `select`s its own card, so a delta rebuilds one card only.

**Live prices without per-card sockets:** cards never open a socket. A `LiveWhenVisible` wrapper (package `visibility_detector`, fraction ≥ 0.5, update interval 300 ms) mounts a `Consumer` that watches dev-realtime's `liveQuoteProvider(instrumentId)` (autoDispose family over `MarketRepository.watchQuotes`). Off-screen or hidden tab (FR-86 visibility signal) → listener gone → provider disposes → `watchQuotes` cancel → `MarketSocket` ref-count drops → server unsubscribes (≤ 1 s, FR-63). Two cards on RELIANCE share one server sub. Card JSON carries the snapshot, so the card paints at once; the snapshot is stale under §3.1 until the first live frame. **Off-screen lifetime:** the element is disposed; card data stays in controller state (≤ 50 answers × 4 cards × 8 KB ≈ 1.6 MB worst case); scrolling back rebuilds from state and resubscribes.

**Mini chart:** reuse v1 `CandleChart` with `ChartType.line`, `baseline: prevClose`, plus two new flags `interactive: false`, `showVolume: false` (no gestures in a scrolling list); the last point is replaced by the live LTP. No second chart painter.

**Actions:** `AiActionRouter` maps kinds to dev-trading routes with `source: ai` ("From AI chat" tag). The `ai_chat` feature imports no order or alert repository (architecture review rule + test: 0 POSTs, FR-64).

## 4. Payoff and strategy builder (`features/strategy/`)
- **Expiry P&L per leg** (q = lots × lotSize, s = +1 buy / −1 sell): CE `s·q·(max(S−K,0) − premium)`, PE `s·q·(max(K−S,0) − premium)`. Sum is piecewise linear with kinks only at strikes, so it is solved **exactly**, not sampled: evaluate at S = 0 and each strike; right-tail slope = Σ s·q over CE legs, left tail ends at S = 0.
- **Max profit:** "Unlimited" if right slope > 0, else max of the kink values. **Max loss:** "Unlimited" if right slope < 0, else min of the kink values. **Breakevens:** linear interpolation of each sign change between kinks, plus the right tail. **Net premium** = −Σ s·q·premium (debit shown negative). Premium = LTP when the leg was added (shown per leg).
- **Today line:** Black-Scholes value per leg at T = time to expiry (market-hours clock), per-leg IV and r from the chain, using the shared pure-Dart `option_math` (same code the engine uses). 121 sample points across the range, recomputed on leg change and throttled to 1 Hz on spot/IV change (4 legs × 121 ≈ 0.1 ms). Hidden with "Today line needs live prices" if any leg is stale.
- **Range:** x from min(strikes, spot) − 6% to max(strikes, spot) + 6%; y from both curves + 10%; unlimited tails clipped with an arrow.
- **Painter:** a pure `PayoffGeometry` (points, breakevens, range) built in the controller, never in `paint`. `PayoffChart` = static `CustomPainter` (fills `upTint`/`downTint`, expiry line, dashed today line, zero line, spot line, breakeven dots) in its own `RepaintBoundary` with `shouldRepaint` on geometry identity, plus a crosshair overlay painter driven by a `ValueNotifier<double?>` (`repaint:`), so drag never repaints curves. Tap is the drag alternative; tooltip is a widget that flips near edges; `selectionClick` on breakeven crossings only.
- **Small screens:** 220 dp in the builder, 140 dp in the card (no crosshair, tap → builder); 4–5 ticks, compact ₹ (`₹15.9K`, `₹1.2L`); breakeven labels closer than 48 dp stack below; chart label scale capped at 1.3, while chips under the chart carry the full risk text at any scale; semantics summary per 03b 5.11.
- **State:** `StrategyBuilderController` (one per screen) reads legs from a keep-alive `StrategyDraftRepository` (chain "Add to strategy" writes there while the builder is closed). Route args can replace the draft: one leg from the ticket "Payoff ›" (FR-70) or legs from the AI `view_payoff` action. Leg rows: side, lots, Trade (prefilled single-leg ticket), ✕; a 5th add shows "Up to 4 legs in preview".

## 5. Interfaces
- **dev-realtime:** (a) the option instrument id format and whether contracts can be subscribed on the quote path (chain snippet = up to 10 contract subs + underlying; FR-63 says the quote path; ≤ 2 cards visible keeps it ≤ 25 of the cap of 100); (b) `liveQuoteProvider(id)` autoDispose family and the FR-86 visibility provider; (c) server-side engine reads for the answer builder: `quote(id)`, `chainSnapshot(und, expiry, around: 2)` with PCR, max-OI strikes, IV; `topMovers(n)`; 5m candles; all stamped with `asOf`; (d) ownership of `option_math` (BS price + IV) as a shared package used by server and client.
- **dev-trading:** routes and args: `OrderTicketArgs {instrumentId, side, lots, product?, source}`, `AlertArgs {instrumentId, price?, source}`; `ChainArgs {underlying, expiry, strike}` (strike centred and outlined); builder route `StrategyArgs {legs}`; the ticket's "Payoff ›" link passes one leg; the ticket owns stale blocking (PRD Q7).
- **dev-perf:** no disk cache for chat (FR-66 is session-only; nothing to warm). Asks: agree the 50 ms delta coalescing, new trace marks `ai_first_card_painted` and `ai_stream_done`, include chat scrolling with 2 live cards in a frame run, and confirm the AI and builder screens stay lazy (FR-82).

## 6. Risks and rejected alternatives
| Item | Decision / mitigation |
|---|---|
| WebSocket for AI | Rejected (PRD §10 Q6): it would consume market `seq`, a lost card would force a resync, cancel is harder to test |
| SSE | Rejected: same streaming as NDJSON with extra `event:/data:` framing and no Dart client advantage; NDJSON is curl-testable |
| One JSON response | Rejected: fails FR-60 (first card before the stream ends) |
| Server sends payoff curve points | Rejected: ties data to screen size; exact kink math is cheap on the client. Server still sends `summary` so the card paints without math, and a test checks both agree |
| Sampling payoff for max/min | Rejected: misses kinks between samples |
| Card owns a socket / keep-alive off-screen cards | Rejected: breaks NFR-14 and the quote cap |
| Risk: shelf buffers output | `buffer_output: false` + server test that the first line arrives before `done` |
| Risk: fast fling churns subs | 300 ms visibility interval; ref-counted socket absorbs repeats; unsubscribe still ≤ 1 s |
| Risk: grammar too narrow | Chips and follow-up chips steer users; fallback lists what works (FR-65); table-driven parser tests |

## 7. Critiques and answers (critique round)
**Answers given**
- **dev-realtime** (ids only, `subscribeQuotes` with `throttleMs` 1000, NDJSON off the socket): agreed. I use the `NIFTY-261110-24500-CE` id format. The card snapshot stays, but only for first paint, carrying its own `asOf`. It goes stale under §3.1 like any other value, so it is not a second source of truth. The today line uses `option_math` `bsPrice`/`valueToday`.
- **dev-trading** (`openOrderTicket`, `openChain(ChainTarget)`, `openAlertCreate`): agreed. The AI passes `side` and `lots: 1`, and **never `limitPrice`**. The opener's risk-notice gate also covers the AI path.
- **dev-perf** (no persistence; onCancel/onResume): agreed. Cards mount their price `Consumer` only when at least 50% visible, then follow the shared rule.

**Critiques raised**
- **dev-realtime:** (1) Define how `throttleMs` merges across ref-counted holders: the minimum wins, and the socket re-sends when a holder leaves, together with the mode union. (2) Add an exact `payoffSummary(legs)` (kink analysis) to `option_math`, so the server's card summary and the client builder share one implementation.
- **dev-trading:** There is no builder hook yet. Chain "Add to strategy" should call `StrategyDraftRepository.addLeg`, and the ticket's "Payoff ›" should call `openStrategyBuilder(StrategyArgs(legs: [leg]))` (FR-29, FR-70). A 5th leg should show "Up to 4 legs in preview".
- **dev-perf:** FR-63's 1 s budget is a sum: detector interval + autoDispose + 300 ms linger + server unsubscribe. Pausing the AI tab's listeners must not stop an answer that is still streaming. I asked again for the `ai_first_card_painted` and `ai_stream_done` marks.

**Changes I now make**
- The `visibility_detector` update interval goes from 300 ms to **200 ms**, leaving room under 1 s for the 300 ms linger.
- Live cards subscribe with `throttleMs: 1000` (1 Hz ticking in chat).
- Payoff math moves from §4 into `option_math` `payoffSummary` (if dev-realtime agrees). The server card `summary` and the builder both call it, so the separate test that checked they agree is no longer needed.
- `trade` action args drop any price: `{instrumentId, side, lots: 1}` only.
- The chat controller has no `onCancel` logic. Only price providers pause, so hiding the AI tab never cancels an answer (as in §3).
