# Note for Codex (updated 12 Nov 2026)

The user decided: **Codex builds, Claude verifies.** You are the only writer. Claude will not edit code until you post that you are done.

## What changed since 9 Nov
- Claude fixed the AI chat layout. The floating chat shortcut stays where it is: bottom-right, above the composer and chips. The list bottom padding matches it, and both sides have 16 pt padding. **Do not remove or move any existing button, shortcut or nav element.** If a layout fix seems to need that, leave a note in thread `build` instead.
- A clean copy was published to a separate public repo. Ignore it and work only in this folder.

## Still open on the board (work in this order)
1. **S-53** (in progress), then S-55, S-56, S-57, S-58: chart tools.
2. **B21**, foldable phones, together with **B25–B28** (found on the Pixel 9 Pro Fold emulator on 12 Nov; see `docs/team/bugs.md`). Check them on the `Pixel_9_Pro_Fold` AVD: `adb shell cmd device_state state 0|1|2` folds, half-opens and opens it. The full spec is in `docs/team/bugs.md`:
   - a hinge-aware two-pane split using `MediaQuery.displayFeaturesOf`;
   - tabletop posture;
   - the flip cover screen at 260 dp;
   - live fold and unfold with no state loss;
   - tests for each.
3. Failure-case suites S-63, S-64, S-65.
4. Accessibility S-69, then the Should items S-71, S-72, S-73.
5. Perf S-47, S-48, S-76 and R-5. Where a step needs a real device, write the harness and tests, then mark the story `blocked` with the note "needs device run".

Each story's acceptance criteria are in `docs/07-stories.md` and `docs/07-stories/cr1.md`.

## Rules (unchanged)
Follow `docs/team/build-brief.md` and `docs/10-change-request-2.md`, and keep coverage at 100%. Log progress to the dashboard with `team.py`, and never edit `events.jsonl` by hand. Do not commit or push.

If you change server code, restart the market server on port 8080 (`cd market_server && dart run bin/server.dart --port 8080`).

## When you are done
All of these must pass:
- `flutter analyze --fatal-infos`
- `flutter test --coverage` with `tool/ci/coverage_check.dart` at 100%
- `tool/ci/file_length_check.dart`
- `tool/ci/deny_list.sh`
- `test/architecture`
- `dart analyze` and `dart test` in `market_server` and `packages/option_math`
- `flutter build web`

Then post `python3 $T say --from manager --thread build "Codex done: <numbers>"` and stop.
