# 03b Part 12: Feedback styles (v2.0)

Owner: ui-designer. Rules from PRD FR-156 and FR-157: **one snackbar at a time**, one feedback service, no widget calls `ScaffoldMessenger` directly. The same priority rule decides which surface is used.

## 12.1 Which surface for which message

| Message | Surface | Why |
|---|---|---|
| Result of a user action, short-lived (order filled, link not available, copied) | **Snackbar** (`SpSnack`) | Transient and dismissible |
| State of the app that persists while true (prices not live, offline, market closed, demo clock) | **Banner** under the app bar | Stays until the state ends; not a toast |
| A problem with one field, one sheet or one card (validation, rejected order inside the ticket, load failed in a card) | **Inline error** next to the thing | Shows where the user can fix it; survives screen rotation and keyboard |
| Nothing to show or total failure of a whole screen | `EmptyView` / `ErrorView` (5.14) | Not a feedback toast |

Never use a snackbar inside a sheet that has the confirm button (it would sit over the button): use the inline banner in the sheet.

## 12.2 Snackbar (replaces and extends 5.13)

- Floating, radius `m`, `inverseSurface` background and `onInverseSurface` text (dark theme: light surface; light theme: dark surface, both at least 7:1), 16 dp horizontal margin, 12 dp above the nav bar; max 2 lines `body`; a leading 20 dp status icon (check, info, alert) for non-colour meaning; optional one text action (`View`, `Undo`, `Retry`) 48 dp tall in `accent`-on-inverse (inverse accent `#8FC3FF` on dark inverse, check 7:1 or higher at implementation).
- **One slot.** A repeat with the same key (or shown under 4 s ago) is dropped. A different message replaces the visible one with no stacking and no queue of more than one waiting item (newest wins).
- **Priority (FR-157):** order outcome > error > info. A lower-priority message never replaces a higher one; it waits one slot.
- **Durations:** info 4 s; with an action 6 s; **order rejection or status unknown** persists until dismissed (swipe or `Dismiss`/`View`).
- Timer pauses while the user holds the snackbar and while TalkBack/VoiceOver focus is on it.
- Announce through `SemanticsService.announce` with the same text; icon is decorative.
- Motion: 200 ms in, 150 ms out; 0 ms under reduce motion.

## 12.3 Banner (`SpBanner`)

- Full width under the app bar (below the market pills), min 36 dp (grows with text), 16 dp padding, 1 dp bottom `outline`.
- Variants: `warn` (`warnTint` on `surface0`, `warn` icon and text: `Prices not live since 10:42:07`), `info` (`infoTint`, `info`: `Demo clock 10:00`, `Market closed`), `neutral` (`surface1`, `textSecondary`: `Offline. Showing saved data`). Error variant is not a banner.
- Text colours pass AA on their tint (warn 5.93 light, 10.57 dark; info 6.67 light, 8.65 dark). Always icon plus words.
- One banner row at most; if several states apply the highest priority wins (offline > stale feed > market closed > demo clock) and the others fold into the status pills. Optional trailing text action (`Retry`, 48 dp). Not dismissible while the state is true.
- `Semantics(liveRegion: true)` on the banner so changes are announced once, not repeatedly.

## 12.4 Inline error (`SpInlineError`)

- 16 dp icon plus `caption`/`body` text in `down` colour is **not** used for non-price errors (red stays for price direction and Sell): errors use the dedicated `error` role = `down` token because there is no other red in the system, but **always with an icon and words**; tint background optional (`downTint`) for blocks inside sheets.
- Field-level: below the field, 4 dp gap, text e.g. `Enter a quantity in lots`; the field outline becomes 2 dp error colour. Block-level (rejection inside the ticket): `downTint` strip above the confirm button with `Rejected: Insufficient funds`, `Retry` only when retry is safe (never on Pending, 5.5b).
- Announce via `Semantics(liveRegion: true)` once on appearance; focus moves to the first invalid field on submit.
- Text contrast: `down` on `downTint` over surface0 or surface1 stays above 4.5:1 (dark 6.0 or more, light 5.0 or more at 14% tint; verify in golden tests).

## 12.5 Haptic and sound pairing

Order fill = success haptic, rejection = error haptic (7). Banners, info snackbars and inline errors have no haptic. Everything also has a visible equivalent.
