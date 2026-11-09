# Batch 2 brief: finish W1, new bugs, close the review queue

Rules, ownership and done criteria are the same as `docs/team/fix-1-brief.md`, with the 100% coverage gate in force. Read your stories in `docs/07-stories.md` / `docs/07-stories/cr1.md` and your LLD.

**Check the code before you build.** Other sessions and FIX-1 already built parts of several stories (e.g. the watchlist, stock page, socket, picker and icons). For each story:
- if it is already done, prove it with tests against its acceptance criteria, then set it to `review`;
- if it is half-built, finish it.

| Owner | Stories (W1) | Bugs (`docs/team/bugs.md`) | Close from the review queue |
|---|---|---|---|
| dev-realtime | S-8 debug hooks, S-9 client time and freshness, S-10a socket v2 and resync, S-10b MarketRepository | B10 OI drift | S-5, S-6, S-7 |
| dev-trading | S-17 watchlist, S-18 stock page, S-59 SpPicker | B9, B11, B14, B15 | S-15, S-16 |
| dev-ai | S-22 postLines and card models, S-52 indicator maths | B12, B13 | S-19, S-20, S-21 |
| dev-perf | S-61 app icon and native splash from `stock_pulse/assets/brand/*.svg` (Android adaptive + iOS sizes, light and dark splash matching the first frame) | — | S-11, S-12 |

"Close from the review queue" means: check the story's acceptance criteria against the current code and tests. Then set it to `done` with a one-line note, or fix the gap.

**At the end:**
1. Run your checks.
2. Update the board for each story and bug (`python3 $T task <id> review|done --owner <you> --note "..."`).
3. Return under 100 words with numbers.

**dev-perf runs last:** regenerate `test/coverage/all_imports_test.dart` after the others report.
