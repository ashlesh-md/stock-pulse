# 03 · UX spec part 15: Strings and copy tone; splash and first launch (v2.0)

Owner: ux-designer · Part of `../03-ux-spec.md` v2.0 · PRD §4.14 FR-160…FR-164, §4.15 FR-170…FR-172, NFR-1…NFR-3,
NFR-22

## 15.1 Strings go through the localisation layer

- **All copy in this spec is the English source text** for ARB keys (`app_en.arb`). No screen hard-codes text
  (FR-160); symbols, numbers and debug Socket Lab frames are the only exceptions.
- Key naming: `<feature>_<element>_<purpose>`, e.g. `chart_studies_limit`, `ticket_confirm_reason_stale`,
  `link_invalid`. Snackbar keys in part 12 are also the ARB keys.
- **Placeholders, not concatenation** (FR-161): "Filled: {side} {qty} {symbol} at {price}" is one ICU message;
  plurals ("1 lot" / "{count} lots", "Delete {count} drawings") are ICU plurals. Word order is the translator's.
- **Numbers, ₹ and times** come from the one formatter (FR-162): ₹ with lakh/crore grouping and 2 decimals for
  amounts, prices to the instrument's tick decimals, percentages with sign and 2 dp, times `hh:mm:ss` 24 h IST,
  dates `11 Nov`. Short volume `1.2L`, `3.4Cr` are formatter output, not copy.
- **Layout must survive +40 %** (pseudo-locale, FR-164): labels wrap, they do not truncate; numbers are never
  truncated or ellipsised. The Confirm label moves the price to a second line before it shrinks
  ("BUY 10 RELIANCE" / "@ 1,480.00"). Segmented pickers fall back to sheets (part 11).
- Icons and images come from `AppIcons` / `AppAssets` (FR-163); the spec names icons by meaning (bell, clock,
  hourglass), ui-designer maps them.

## 15.2 Copy tone rules

| # | Rule | Yes | No |
|---|---|---|---|
| 1 | Say what happened, then what to do | Couldn't load 15m · showing 5m | Error loading data |
| 2 | Short, plain, present tense; sentence case | Price not live since 10:02:14 | The Price Is Currently Not Live |
| 3 | Exact numbers with units; never round money | ₹18,362.50 | ~₹18k |
| 4 | Trader's words, consistent glossary: Buy / Sell, lots, LTP, Pending, Filled, Rejected, Stale, Closed | Pending | Processing, In progress |
| 5 | No blame, no alarm, no exclamation marks, no emoji in copy | Order status unknown. See Orders | Oops! Something went wrong! |
| 6 | No codes or internals | Session expired · Restart demo | 401 Unauthorized |
| 7 | Honest about simulation; never imply advice or profit | Simulated. Not advice. | Great trade, safe bet |
| 8 | Buttons are verbs naming the object | Set alert, Buy limit at 1,512.35 | OK, Submit |
| 9 | Disabled things say why, in the same place | Market closed · opens 09:15 | (silent grey button) |
| 10 | No "please" / "sorry" padding; one idea per line | Needs connection | Sorry, please check your connection and try again |
| 11 | Times are server time, labelled "as of" or "since" | as of 10:02:14 | 5 seconds ago |
| 12 | Middle dot `·` separates a message from its action or a second fact | Link not available | Link not available! Click here |

## 15.3 Splash and first launch

**Goal:** the trader sees their own watchlist, not a logo, as fast as possible (NFR-1 first frame p50 ≤ 800 ms,
NFR-2 cached content p50 ≤ 1.0 s, NFR-3 first live tick p50 ≤ 2.0 s).

| Moment | What the user sees | Rule |
|---|---|---|
| Tap icon | **Native splash only**: brand background + centred mark, light or dark per system (FR-171, FR-172) | No Flutter splash route, no animation, no minimum time |
| First Flutter frame | Splash removed; the **shell with the Watchlist** and cached rows in stale style "as of 15:30 yday" | Cache read is not awaited before `runApp`; if it is not ready the first frame shows static placeholder rows and swaps to cached rows when read (no spinner overlay) |
| ≤ 2 s | Rows turn live one by one on their first frame; badge Live | — |
| After first frame | Push, analytics and other init start (NFR-22) | Nothing visible; failures silent (F15, F16) |

**First launch (no cache, fresh install):**

- First frame: Watchlist with the 3 default symbols' names (local metadata) and placeholder price bars, badge
  "Connecting…", `MarketStatusPill` and Demo clock chip. No zeros.
- **No prompts at launch:** no notification permission (asked after the first alert, part 13), no F&O risk notice
  (shown before the first F&O ticket), no onboarding carousel, no cookie/consent wall.
- Server unreachable → F1: "Connecting… · Retry" on the list, badge Offline.

**Warm resume:** no splash; the last screen as it was; prices grey until the first live frame after resubscribe
(FR-85, FR-86).

**Cold start from a link or push:** native splash → first frame is the link target with its back stack (part 13
§13.1 rule 1); never a Watchlist flash first.

**App icon:** one master, adaptive + monochrome themed icon on Android, all iOS sizes (FR-170); ui-designer owns
the artwork.
