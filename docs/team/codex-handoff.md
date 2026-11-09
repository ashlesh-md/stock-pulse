# Note for Codex (9 Nov 2026)

The user decided: **Codex builds, Claude verifies.** Claude's agents are stopped and will not edit code until you are done, so you are the only writer.

## Still open on the board
- In progress: S-28b, R-5.
- To do: about 19 stories (see the dashboard at http://localhost:8095 or `python3 tools/agent-team/scripts/team.py --dir docs/team status`).
- New user request **B21: foldable phones**. The full spec is in `docs/team/bugs.md`:
  - hinge-aware two-pane split with `MediaQuery.displayFeaturesOf`;
  - tabletop posture;
  - flip cover screen at 260 dp;
  - live fold and unfold with no state loss;
  - tests for each.
- Bugs B9–B15 from batch 2 were partly done by Claude's agents before they stopped. Check each against `docs/team/bugs.md`.

## Rules (unchanged)
Follow `docs/team/build-brief.md` and `docs/10-change-request-2.md`, with coverage at 100%. Keep logging to the dashboard with `team.py`, and never edit `events.jsonl` by hand.

## When you are done
All of these must pass:
- `flutter analyze --fatal-infos`
- `flutter test --coverage` with `tool/ci/coverage_check.dart` at 100%
- `tool/ci/file_length_check.dart`
- `tool/ci/deny_list.sh`
- `test/architecture`
- `dart analyze` and `dart test` in `market_server` and `packages/option_math`
- `flutter build web`

Then post `python3 $T say --from manager --thread build "Codex done: <numbers>"` and stop. The user will ask Claude to verify. Do not commit or push.
