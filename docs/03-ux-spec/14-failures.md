# 03 · UX spec part 14: Failure states F1–F18 and empty states (v2.0)

Owner: ux-designer · Part of `../03-ux-spec.md` v2.0 · PRD §7a (F1…F18, NFR-21), §7 (E1…E20)

Rules for every row: no crash, no blank screen, no fake zero, no endless spinner (10 s → Error with Retry), no
order placed, cancelled or duplicated. Snackbars follow part 12 (one at a time). Codes (`401`, `5xx`) are never
shown to the user. Screen abbreviations: **WL** Watchlist · **SP** Stock page + chart · **CH** Option chain · **TK**
OrderTicket · **PF** Portfolio · **AL** Alerts · **AI** AI chat · **MO** More/Settings.

## 14.1 Failure map

| # | Failure | Global chrome | What each affected screen shows |
|---|---|---|---|
| F1 | Network down at cold start | Badge **Offline**; stale banner after 5 s | **WL/PF:** cached rows grey "Stale since 15:30 yday"; no cache → 8 static placeholder rows + "Connecting… · Retry". **SP:** cached candles or `ErrorView` "Chart unavailable · Retry". **CH:** "Connecting… · Retry" if no snapshot. **AI:** composer disabled "Chat needs connection". **TK:** opens, Confirm disabled "Offline · reconnecting…" |
| F2 | Network drops mid-session | Badge Reconnecting → Offline; banner "Prices not live since hh:mm:ss" | **WL/CH/SP:** values dim within 5.25 s, last candle frozen. **TK:** inputs kept, Confirm disabled with reason. **PF:** P&L dimmed "as of"; Pending rows' Refresh status disabled "Waiting for connection" only when Offline. **AL:** list readable, Save disabled "Needs connection". **AI:** stream stops, received cards kept, error card "Answer interrupted · Retry" |
| F3 | REST timeout | — | **Reads (any screen):** one silent retry, then inline `ErrorView` "Couldn't load <thing> · Retry"; cached content stays above it. **TK (POST):** "Placing…" → after 3 s "Checking status…" → if still unknown, sheet closes, snackbar "Order status unknown. See Orders · View", Orders row **Pending** with Refresh status only |
| F4 | 400/422 validation | — | **TK:** server reason as the inline rejection banner at the top of the sheet, sheet scrolls to it, rejection haptic (e.g. "Price outside band 1,193.60–1,790.40"). **AL:** reason under the price field |
| F4 | 401 bad token | **Session banner** (proposal Q-UX-3): "Demo session expired · Restart demo" persistent under the app bar; until then the PRD's single snackbar applies | All server actions disabled with "Needs a new session"; cached content readable; no retry loop |
| F4 | 404 unknown id | — | **PF/AL:** the row disappears on refresh; if the user tapped it, snackbar "That order is no longer available" (key per id). **Deep link:** part 13 |
| F4 | 409 duplicate key | — | Nothing extra: treated as the original order; one outcome snackbar only |
| F4 | 429 rate limit | — | Buttons stay enabled; the request waits (`Retry-After`, default 2 s) behind the same spinner; no snackbar, no extra taps sent |
| F5 | 5xx | — | As F3: reads retry once after 1 s then inline error; POST retries with the same key then Pending |
| F6 | Malformed data | — | **Bad REST body:** inline `ErrorView` for that section. **Bad socket frame:** nothing visible (dropped; a skipped seq triggers resync, Reconnecting badge may blink). **Unknown AI card:** rendered as a text card. **Bad cache:** cold start like no cache (F1), no message |
| F7 | Server restart | Reconnecting → Live ≤ 10 s | All screens keep last values grey "as of", then live after resync; **TK:** Confirm disabled until live; **PF:** orders/positions reload, nothing announced twice; **SP:** candle gap refetched, drawings untouched |
| F8 | Device clock skew | — | Nothing different: every "as of" and candle time is server time |
| F9 | Empty data | — | See §14.2 |
| F10 | Notifications denied | — | **MO:** "Notifications · Off · Turn on in system settings ›"; **AL:** in-app banners unchanged; no repeat prompts |
| F11 | Storage write fails | — | Nothing, except drawings: snackbar "Couldn't save drawing" (once per kind); app works from memory |
| F12 | App killed mid-order | — | Relaunch: **PF › Orders** shows server truth (Filled / Rejected / Pending); one outcome snackbar and one haptic; nothing resubmits |
| F13 | Backgrounded during stream | — | Resume: prices grey until live; **AI:** request cancelled, cards kept, "Answer stopped" info snackbar only if the user returns to the AI tab |
| F14 | Bad deep link / push payload | — | Link: nearest screen + "Link not available". Push: app opens on the last tab, no snackbar |
| F15 | Push init / token failure | — | Nothing; MO row shows "Not available on this build" |
| F16 | Analytics sink fails | — | Nothing |
| F17 | Repeated bad taps | — | Disabled Confirm: reason line focus + light haptic, **no** snackbar. Any repeated snackbar key within 4 s is dropped (part 12) |
| F18 | Missing string or asset | — | English text; the registry's neutral placeholder icon (never an empty box or a red error widget) |

## 14.2 Empty states (F9)

Each is an `EmptyView`: 1 line of what is empty, 1 line of why or what to do, and one action button in the thumb
half where possible. Never zeros, never "No data".

| Screen | When | Copy | Action |
|---|---|---|---|
| WL | No symbols | Watchlist is empty · Add stocks to follow their live price | `Search stocks` · `Restore NIFTY, RELIANCE, HDFCBANK` |
| WL search | No match | No simulated stock matches "TATAX" | — |
| SP chart | No candles for the range | No chart data for 1D yet | `Show 1W` |
| SP chart study | Period > candles | Chip "Not enough data for SMA(200)" | Edit study |
| SP chart study | VWAP on 1d/1w | Chip "VWAP: intraday only" | Pick an intraday interval |
| CH | No chain for the symbol | No options for this instrument | `Open NIFTY chain` |
| CH | Expiry list empty | No expiries available right now | `Retry` |
| PF Positions | None | No open positions · Positions you open today show here | `Open the chain` |
| PF Holdings | None | No holdings yet · Shares bought with CNC show here the next trading day | `Go to watchlist` |
| PF Orders | None today | No orders today | `Go to watchlist` |
| AL | None | No alerts yet · Get told when a price crosses a level | `New alert` |
| AL Triggered | None | Nothing triggered yet | — |
| AI | First open | Greeting + suggested prompt chips (main spec §7) | Chips |
| Strategy | No legs | Add legs from the option chain | `Open chain` |
| Socket Lab | No frames | Waiting for frames | — |

## 14.3 Load states quick reference (deep links and cold start)

| Screen | Load with cache | Load without cache |
|---|---|---|
| WL, PF | Cached rows, stale style | 8 / 4 static placeholder rows, "Connecting…" |
| SP | Cached header + candles, stale | Header placeholder, plot box with one spinner |
| CH | Last snapshot dimmed "as of" | Header first, placeholder rows with an empty ATM marker |
| TK | — | Header + inputs disabled "Loading contract…" until metadata; Confirm disabled |
| AL, AI | Cached list / greeting | Placeholders / greeting |
