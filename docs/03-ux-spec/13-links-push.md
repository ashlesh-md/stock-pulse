# 03 · UX spec part 13: Deep links and push taps (v2.0)

Owner: ux-designer · Part of `../03-ux-spec.md` v2.0 · PRD §4.16 FR-175…FR-181, F14, F15, F10

Both schemes (`stockpulse://…` and `https://stockpulse.example/app/…`) open the same go_router path. A link is a
**navigation**, never an action: it can prefill, it cannot submit, confirm, cancel, modify, reset or change a
setting (FR-178).

## 13.1 Entry points

| Path | Opens | Back stack (Back goes to…) | Needs data | Invalid → |
|---|---|---|---|---|
| `/watchlist` | Watchlist tab | — (tab root) | Cache-first | — |
| `/stock/{symbol}?range=&interval=` | Stock or index page; chart at range/interval if valid | Watchlist | Quote + candles: page shows its own Load state | Unknown symbol → Watchlist + `Link not available`; bad range/interval → page with remembered values + `Link not available` |
| `/stock/{symbol}/chart` | Full-screen landscape chart | Stock page → Watchlist | Candles | As above |
| `/options/{underlying}?expiry=` | Options tab, that underlying + expiry, ATM centred | Options root (that chain is the root) | Chain | Unknown underlying → Options (last viewed) + `Link not available`; missing expiry → nearest, silent; expired → nearest + `11 Nov expired · showing 18 Nov` |
| `/trade/{symbol}?side=&type=&price=` | Stock page, then the `OrderTicket` prefilled, tagged "From link" | Ticket closes to the stock page → Watchlist | Metadata (lot, tick, band) before the ticket is usable | Index or unknown symbol → stock page / Watchlist + `Link not available`; bad or missing `side`/`type` → stock page **without** the ticket + `Link not available` (never guess a side: a wrong default is wrong information) |
| `/portfolio/{tab}` | Portfolio, sub-tab positions / holdings / orders | Portfolio root | Cache-first | Unknown tab → Positions + `Link not available` |
| `/orders/{orderId}` | Portfolio › Orders, row highlighted (2 dp accent outline, 3 s) and scrolled into view | Portfolio root | Orders list | Unknown id → Orders + `Link not available` |
| `/alerts` | Alerts list (under More) | More root | Alerts | — |
| `/alerts/new?symbol=&price=` | Alerts list + create sheet prefilled | Sheet closes to Alerts → More | Quote for direction and "% away" | Unknown symbol → Alerts list + `Link not available`; bad price → form with price empty |
| `/ai?q=` | AI chat, question in the composer, **not sent** | AI root | — | Empty `q` → plain chat; `q` cut to 200 characters |
| Debug paths (`/more/socket-lab`, clock) | Release: invalid; debug builds: the screen | More root | — | Release → Watchlist + `Link not available` |

### Rules for all links

1. **Cold start:** the router's first location is the link, so the first frame is already the target screen (no
   Watchlist flash), with the back stack built underneath (FR-176). Cache-first applies to the target; prices are
   stale "as of" until live.
2. **Needs data:** the target shows its normal Load state (part 14 lists them). It never shows a blank screen and
   never a spinner that does not end (10 s → Error with Retry).
3. **Warm or foreground link while something is open:**
   - Ticket in **Placing / Checking**: the link waits until the outcome is known, then opens.
   - Ticket open with inputs, not placing: the ticket closes (nothing was submitted) and the link opens.
   - Any other sheet or dialog: closes, link opens.
   - F&O risk notice: the link opens; the notice shows again on the next F&O ticket.
4. **Trade links** open the same ticket as a tap would: Confirm needed, stale block, reason line; price snapped to
   tick; a price outside the band stays in the field with the field error (the trader sees why); `type=limit`
   without a price prefills the LTP once live. 0 POSTs from the link itself.
5. **One snackbar** per invalid link, priority Error, key `link_invalid` (part 12). A link that is partly invalid
   opens the nearest valid screen with the valid parts applied.
6. Links update "last viewed" (Options underlying, chart range/interval only if the trader then changes them; a
   link's range/interval is for that view only and does not overwrite the remembered app-wide choice, FR-147).

## 13.2 Push notification taps (placeholder flows, FR-179…FR-181)

Real delivery is out of scope; the `PushService` is a no-op by default. The flows below are what the app does
when a (fake or future real) notification is tapped. Payload `{type, id, link}`.

| Type | Tap opens | Dedupe | Notes |
|---|---|---|---|
| `alert` | `link` (normally `/stock/{symbol}`) with the alert strip "Alert hit: ≥ 1,500.00 at 10:02:11" above the bar (same as banner tap) | `alertId` seen-set (FR-55): if the in-app banner already showed it, the tap still opens the page but no second banner | Buy/Sell is 1 tap from there |
| `order` | `/orders/{id}` row highlighted | Order outcome already announced → no second snackbar | Pending orders refresh on open |
| `system` | `link` if valid, else Watchlist | — | E.g. expiry day reminder |
| Unknown type or bad link | App opens on the last tab, **no snackbar** (the user did not ask for a specific screen); logged once (F14) | — | |

- **Foreground message:** never shown as an OS notification; alerts use the in-app banner as today.
- **Permission (FR-181):** never at launch. After the trader saves their **first alert**, a one-time explainer sheet:

```
┌────────────────────────────────────────┐
│ ── Get alerts when the app is closed?  │
│ StockPulse can notify you when a price │
│ crosses your level. Alerts inside the  │
│ app work either way.                   │
│ [ Not now ]            [ Turn on ]     │ Turn on → OS prompt
└────────────────────────────────────────┘
```

  "Not now" or OS denial: in-app alerts unchanged; not asked again except from Settings.
- **Settings row** "Notifications": `On` · `Off · Turn on in system settings ›` · `Not asked yet · Turn on ›`
  (F10). Init or token failure (F15) shows nothing to the user.
