# 01 · Discovery brief: StockPulse v2

Owner: business analyst · Status: done · Input: `00-intake.md` · Next: PRD (product manager)

> Every price in StockPulse is simulated. Market facts below were checked on 6 Nov 2026 against public
> sources. Anything marked **(unverified)** came from one secondary source or none, so check it before
> it goes into copy or tests.

---

## 1. Problem statement

Indian retail F&O and equity traders do almost everything on their phones, and the moments that matter
are short and crowded: the 09:15 open, the last hour of an expiry day, a two-minute gap between meetings.
In those moments today's apps can show **stale prices as if they were live**, freeze the order sheet,
spread one decision across four screens (chain → strike → order → positions), or take seconds to start.
StockPulse v2 has to show a trader **what is true now, and how fresh it is**, and let them act on it
with one thumb in under three taps, while the network is poor and the load is at its peak.

---

## 2. Personas

| | **Arjun, options intraday trader** | **Meera, swing / positional investor** | **Rohan, new F&O learner** |
|---|---|---|---|
| Age / job | 31, sales manager in Pune; trades on the side | 44, chartered accountant in Chennai | 23, first job in Bengaluru, ~1 year of equity trading |
| Instruments | NIFTY weekly options (buys and sells premium), some stock futures | CNC delivery stocks, a few NRML stock futures held over weeks | Cash stocks; just enabled F&O, buys cheap OTM NIFTY options |
| Capital / size | ₹3–5 L margin; 2–10 lots | ₹40 L portfolio, ~25 holdings | ₹50 k; 1–2 lots |
| Goals | Get in at the open and out the same day; never miss a stop | See day and total P&L at a glance; get alerted at entry/exit levels; avoid watching all day | Understand what the chain is saying; know the max loss before he buys |
| Phone habits | Android, mid-range phone, mobile data on the move; checks the app 50+ times a day; one hand while commuting | iPhone, mostly Wi-Fi; opens the app 3–5 times a day; relies on alerts | Android budget phone, 4 GB RAM, battery saver on; long sessions after work; YouTube + app side by side |
| **Moment that matters** | **09:15 open on expiry Tuesday**: chain ticking, ATM moving, must place and exit in seconds | **Price-alert push in a cab** → open → check the holding → place a limit order in under 30 s | **First option buy**: picks a strike, sees lots × premium and a payoff, then holds it into expiry |
| Pain points | Chain lags or jumps around while scrolling; ATM row scrolls away; order sheet freezes at open; can't tell if a price is live or stale; lot maths done in his head | Holdings and positions confused; day P&L vs total P&L unclear; too many taps from alert to order; app slow to start from a cold launch | Jargon (OI, IV, theta); doesn't know premium × lot size = real cost; surprised by theta decay and by auto square-off; no idea of max loss |
| What wins him/her | Chain pinned at ATM, buy/sell from the row, live P&L ticking, haptic on fill | Instant start with "as of" time, clear P&L summary, alert → order in 2 taps | Plain-language AI answers with cards, payoff before order, risk warnings |

---

## 3. Key moments / jobs to be done

| # | Moment | What they must do | What breaks today in apps | What StockPulse must guarantee |
|---|---|---|---|---|
| M1 | Cold start at 09:14 | Open the app, see positions and watchlist | Spinner for 2–5 s; blank lists; old prices shown as live | First useful frame from cache in < 1 s (target, to be measured); every cached price labelled **stale** until the first live tick |
| M2 | 09:15 open, chain ticking | Find ATM, read OI/IV, buy a strike | Chain janks under 4+ updates/s; ATM row moves off screen; rows re-render whole table | Chain auto-centres on ATM and keeps it pinned; per-cell rebuilds; no dropped frames in profile mode |
| M3 | Place an order under load | Pick qty in lots, set limit/SL, confirm | Sheet freezes; double-tap sends two orders; error hidden behind sheet | Quantity entered in **lots**; idempotent order key (v1 has it); one in-flight submit; errors shown over the sheet; haptic + notice on fill |
| M4 | Network drops in a cab | Keep seeing positions; know if data is live | Prices freeze silently; app looks live but isn't | Visible connection state; "last updated hh:mm:ss" when stale; resync on reconnect (v1 socket has it) |
| M5 | Price alert fires | Get notified, open stock, act | Alert arrives late; opens the home screen, not the stock | Alert streamed over the socket; tapping it opens the stock with the order sheet one tap away |
| M6 | Check P&L between meetings | Day P&L, total P&L, by holding/position | Holdings vs positions mixed up; day vs total P&L unclear | Separate Positions and Holdings tabs; summary card: day P&L, total P&L, invested, current value |
| M7 | Expiry day, last hour | Exit or roll before close; watch theta | Auto square-off surprises; no reminder | Show "expires today" badge and time to square-off on MIS/expiring positions |
| M8 | Learning: "what does this chain say?" | Ask a question, get an answer he can act on | Text-only bots; generic answers; no link to data | AI chat answers as **live cards** (quote, chart, payoff, screener table) built from the app's own data; each card says "simulated, not advice" |
| M9 | Before a multi-leg trade | See max profit, max loss, breakevens | Payoff hidden in a separate product | Payoff diagram from the chain selection, readable on a 360 dp screen |

---

## 4. Competitor scan

Checked on 6 Nov 2026 with web search. Most detail comes from app store listings, broker help pages and
third-party reviews.

| Feature | Zerodha Kite | Groww | Dhan | Sensibull | Upstox | **What StockPulse takes** |
|---|---|---|---|---|---|---|
| Watchlist | Several numbered watchlist tabs, swipe between them; long-press for buy/sell/chart; marketwatch is the home screen | Simple list cards, invest-first look | Watchlists with fast trade buttons | n/a (uses broker watchlist) | Multiple watchlists (unverified detail) | Dense rows, swipe/long-press to buy or sell; per-row rebuilds (v1 already does) |
| Option chain layout | Option chain in the app shows LTP, IV, IV percentile, OI and OI change; native chain launched on Kite Web (beta, Feb 2025) | Customisable option chain, order placement from the chain, "Fast Mode" for F&O | Chain with greeks, IV, PCR, max pain; trade calls and puts from the chain; dedicated Options Trader app | Most detailed chain: greeks, IV, OI analysis (some features paid) | Chain with greeks (unverified detail) | Calls left, strike centre, puts right; **ATM pinned and highlighted**; ITM shading; choose columns (LTP, OI, ΔOI, IV, delta); buy/sell straight from a row |
| Order entry | Bottom sheet; market/limit/SL/SL-M; MIS/CNC/NRML; GTT; "Nudges" warn when price is far from LTP, on surveillance (ESM) stocks and penny stocks | Simple sheet; F&O "Fast Mode" | Super Orders (entry + target + SL), Flash Trade, baskets, Forever/OCO orders; Power Scalper terminal (chart + chain + orders in one view) | Sends orders through the linked broker; strategy baskets | Standard sheet (unverified detail) | One sheet, thumb-zone confirm button, qty in lots, product picker, **Kite-style nudge** when limit is far from LTP; SL as a stretch goal |
| Holdings / P&L | Separate Holdings and Positions tabs; day and total P&L | Expanded positions view; holdings by stock | Positions + holdings; P&L summary | Position analysis with payoff | Separate holdings/positions (unverified detail) | Separate tabs + a summary card; day vs total P&L stated in labels |
| Alerts | Cloud alerts on stocks, futures, options; GTT trigger sends push + email | Price alerts; F&O risk alerts, exposure monitoring, optional trading locks (Safeguard, F&O Pause) | Price alerts (unverified detail) | OI / price alerts (unverified) | Price alerts (unverified) | Price alerts streamed over the socket, push-style banner in app, tap → stock page |
| Charts | TradingView and ChartIQ in app | TradingView-style charts | TradingView charts, "Scalper on Charts" | Payoff charts, OI charts, straddle charts | TradingView charts (unverified) | Keep v1 chart (5 types); add payoff diagram |
| AI / insights | No AI assistant found (unverified) | **GR-1** AI assistant, opt-in beta, reads portfolio and news with consent controls; not shown to do F&O analysis (dates differ across sources) | No AI assistant found (unverified) | Rules-based insights and screeners, not chat (unverified) | Not checked | Chat that answers with **cards and widgets**, not just text; simulated and clearly labelled |
| Startup speed | Known for a light, fast app (no published numbers found, unverified) | Not published | Advertises fast execution (<25 ms, from affiliate reviews, unverified); no startup numbers | Web-first | Not published | **Publish our own numbers**: cold start, time to first live tick, frame times in market hours |

**Takeaways**
1. The **chain is where apps compete** (Dhan's Options Trader, Groww's Fast Mode, Kite's native chain). Trading from a chain row is now expected.
2. **Risk guards are now expected**: Kite Nudges, Groww Safeguard / F&O Pause. A simple nudge is cheap to add and looks good in a demo.
3. **AI that returns widgets is still rare**. Groww's GR-1 is the only big launch we found, and it is a portfolio and research assistant. Cards that answer F&O questions would set StockPulse apart.
4. No broker publishes startup or frame numbers. Measured numbers in our docs cover JD items J5 and J8 and also set us apart.

---

## 5. Domain notes the team must get right

### 5.1 Option chain

| Term | What it means | Rule for StockPulse |
|---|---|---|
| Underlying | The index or stock the option is on (NIFTY, BANKNIFTY, RELIANCE…) | Chain header shows underlying LTP live |
| Strike | Price at which the option can be exercised. NIFTY strikes are 50 points apart | Server builds about ±15 strikes around spot |
| CE / PE | Call (right to buy) / Put (right to sell) | Calls on the left, puts on the right, strike in the middle |
| ATM / ITM / OTM | ATM = strike closest to spot. ITM call: strike < spot; ITM put: strike > spot | Shade ITM cells; pin the ATM row; ATM moves as spot moves |
| Premium (LTP) | Price per unit of the option | Real cost = premium × lot size × lots, **always show the ₹ total** |
| Lot size | Contract multiplier. **NIFTY 65, BANKNIFTY 30** from Jan 2026 series (was 75 / 35) | Qty entered in lots; lot size comes from the instrument, never hard-coded |
| OI | Open interest: contracts still open | Show in lakhs; bar behind the number helps you scan |
| Change in OI | OI now minus OI at the previous close; build-up or unwinding | Green/red by sign, not by price direction |
| IV | Implied volatility, the market's expected volatility backed out of the premium | Show as %; one decimal |
| Greeks | Delta (price sensitivity), gamma (delta change), theta (decay per day, negative for buyers), vega (IV sensitivity) | Computed on the server with Black-Scholes from simulated IV; shown on demand, not all columns by default |
| PCR | Put-call ratio of OI | Optional header stat |
| Expiry | NIFTY weekly expiry is **Tuesday**; the monthly is the last Tuesday. If Tuesday is a holiday, expiry moves to the previous trading day. BANKNIFTY has **monthly only** (weekly contracts stopped in Nov 2024 after SEBI's one-weekly-index-per-exchange rule). Stock options are monthly. BSE Sensex weekly is reported as Thursday (sources conflict) | Expiry picker; "expires today" badge; simulated calendar follows these rules |

### 5.2 Orders and products

| Item | Meaning | Rule |
|---|---|---|
| Market | Fill now at the best price | v1 has it |
| Limit | Fill at this price or better | v1 has it; nudge if > x% from LTP |
| SL (stop-loss limit) | Becomes a limit order when the trigger price is hit | v2 stretch; needs trigger < price rules for sell |
| SL-M | Becomes a market order at the trigger. Exchanges have restricted SL-M for options (unverified, broker specific) | Leave out of options in v2 |
| MIS | Intraday product with leverage; the broker auto squares off before close (about 15:15–15:25, varies by broker, unverified) | Show the square-off time on MIS positions |
| CNC | Cash-and-carry delivery for equity; becomes a holding | Equity only |
| NRML | Overnight F&O carry until expiry or exit | F&O only |
| Tick size | ₹0.05 for most stocks and options | Validate on the client and the server |

### 5.3 Holdings vs positions, settlement, market rules

| Topic | Fact | Rule |
|---|---|---|
| Positions | Today's trades plus open F&O (NRML) positions; P&L marked to market every tick | Positions tab |
| Holdings | Delivery shares in demat; average price; day P&L = (LTP − prev close) × qty; total P&L = (LTP − avg) × qty | Holdings tab with both P&L figures |
| T+1 | Equity settles one trading day after the trade (all stocks since Jan 2023). Shares bought today appear in holdings the next day; an optional T+0 cycle exists for a small set of stocks | Simulate a day roll that moves CNC buys into holdings |
| Price bands | Stocks have circuit bands of 2/5/10/20%. F&O stocks have no fixed circuit but dynamic operating ranges. Index-wide circuit breakers at 10/15/20% | v1 server rejects limits > 20% from prev close; keep it and show the reason |
| Market hours | Normal market 09:15–15:30 IST, Mon–Fri except exchange holidays | Market-status chip: Pre-open / Open / Closed |
| Pre-open (equity) | 09:00–09:15 call auction: order entry 09:00–09:08, matching, then a buffer | Show "Pre-open" and the indicative price; disable market orders |
| Pre-open (F&O) | Since 8 Dec 2025 NSE runs a pre-open call auction for **futures only**, not options. Order entry reportedly ends at a random time from 7 Sep 2026 (unverified) | Options trade only from 09:15 |
| Risk disclosure | SEBI requires brokers to show an F&O risk disclosure ("9 out of 10 individual traders lose money"; the FY22–24 study found 93%) and ask clients to acknowledge it. Whether the login acknowledgement still applies in its original form is unverified | Show a one-time F&O disclosure screen, labelled as a simulation |

---

## 6. Assumptions, risks, open questions

### Assumptions

| # | Assumption |
|---|---|
| A1 | All data stays simulated on the Dart server; real NSE names are used for familiarity only |
| A2 | Scope is NIFTY (weekly) + BANKNIFTY (monthly) options plus a few stock futures; not every F&O stock |
| A3 | No real money, KYC, margin or broker login; a single demo user with a demo token |
| A4 | The AI chat is rule-based on the server (from the intake), streams typed card JSON, and needs no API key |
| A5 | The main device is a mid-range Android phone (about 360×800 dp, 4 GB RAM); we measure performance there or on the closest emulator |

### Risks

| # | Risk | Impact | Mitigation | Owner |
|---|---|---|---|---|
| R1 | **Stale prices shown as live** after a cache-first start or a socket drop | A trader acts on wrong numbers; the worst failure for a trading app | Every quote carries `asOf`; the UI greys it out and shows the time when older than N s; orders blocked or warned when stale | architect |
| R2 | Chain update load: about 30 strikes × 2 sides × several fields at 4 Hz | Jank, battery drain, dropped frames | Server conflation per strike; client subscribes only to visible strikes; per-cell `select` | architect |
| R3 | Simulated data looks fake (IV flat, OI random, greeks inconsistent with premium) | Demo loses credibility with domain experts | Price options from Black-Scholes on a moving spot with an IV smile; OI drifts with seeded trends | developer |
| R4 | Lot size or expiry rules hard-coded and later wrong | Wrong ₹ totals in the demo | Instrument metadata from the server; one config table with a source date | developer |
| R5 | F&O suitability: the app makes options buying look easy | Ethical/regulatory look; poor product judgement in a review | Risk disclosure, max-loss on the payoff, nudges, "simulated, not advice" on AI cards | product manager |
| R6 | AI chat promises more than a rule-based server can do | Answers feel canned or wrong | Small fixed set of question types, with a clear "I can answer…" list of suggestions | product manager |
| R7 | Scope creep: SL, GTT, baskets and strategies all at once | Release slips | MVP = chain + market/limit F&O orders + holdings + alerts + chat + payoff; the rest goes to the backlog | product manager |

### Open questions for the product manager

1. Which underlyings and expiries are in v2: NIFTY weekly only, or BANKNIFTY monthly and stock options too?
2. Is **SL / SL-M** in scope for v2, or are market + limit enough for F&O?
3. Multi-leg strategy orders, or single-leg orders with a payoff preview only (multi-leg payoff as view only)?
4. When a quote is stale, should orders be **blocked** or **allowed with a warning**?
5. Do we simulate the market clock (pre-open, close, MIS auto square-off, T+1 roll) or always run "open"?
6. Do the AI chat cards allow **action** buttons (e.g. "Buy this strike"), or are they read-only?
7. Do we need a one-time F&O risk disclosure screen, and how strong should the nudges be?
