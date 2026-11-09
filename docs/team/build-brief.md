# Build brief (every developer agent reads this first)

Project root: `.`
Server: `market_server/` (Dart). App: `stock_pulse/` (Flutter). Shared package: `packages/option_math/`.

## What to read for your story
1. Your story in `docs/07-stories.md` (acceptance criteria, files, dependencies).
2. Your LLD: `docs/06-lld/<area>.md`, and the binding interfaces in `docs/05-hld.md` §10.2 (use names and signatures exactly).
3. `docs/06-lld/README.md` (decisions D1–D13, CR-1 impact §6), `docs/adr/0009`…`0021` (CR-1 rules) and `docs/08-build-plan.md` (who owns which files this wave).
4. The existing v1 code you are changing. Keep v1 behaviour working unless the story replaces it.

## Rules
- **Only touch the files your story lists.** Other developers are editing other files in the same checkout right now. If you need a change in a file you do not own, post it in thread `build` `--to <owner>` and work around it with a fake or a TODO, never edit it.
- **Tests first** (TDD): write the story's tests from the LLD test list, see them fail, then implement.
- Manual Riverpod 3 providers; hand-written immutable classes with `==`/`hashCode`/`copyWith` and hand-written JSON. **No code generation** (no freezed, json_serializable, riverpod_generator, build_runner).
- **Architecture (CR-1, HLD v2.0 §4, ADR-0009/0010):** four layers per feature. Controllers and their immutable state go in
  `application/`; widgets in `presentation/` only render state and call controller methods; repositories are domain
  interfaces implemented in `data/`; repository providers live in `features/<f>/<f>_providers.dart`; controller providers
  sit next to their controller. One controller + one state per screen or flow by default; a second one needs a reason in
  your LLD. `domain/` and `data/` may use cohesive subfolders such as `entities/`, `models/`, `repositories/`, `dto/`,
  `dao/` and `datasources/` when that makes the feature easier to navigate; do not create folders for a single trivial file.
  Put meaningful business use cases in `domain/usecases/`; keep simple controller-to-repository operations direct.
  `core/providers.dart` is gone: import the exact provider file.
- **Results and errors:** `Success(value)` / `Failure(error)`; errors are `AppError` (`NetworkError`, `ServerError`,
  `ParseError`). Never show `AppError.message` to the user; text comes from `AppStrings` (ADR-0012, ADR-0018).
- **Imports:** `package:stock_pulse/...` everywhere; relative only for `test/helpers/` (ADR-0013).
- **Navigation:** go_router via your feature's `presentation/<f>_routes.dart` and the `open*` helpers; no `Navigator.push`
  of pages, no route strings outside `*_routes.dart` (ADR-0015).
- **Snackbars, analytics, strings, icons:** controllers call `FeedbackController.show` (never `showSnackBar`) and
  `AnalyticsService.log`; widgets use `context.strings`, `AppIcons`, `AppImages`; no literal UI text, `Icons.` or asset paths
  in widgets (ADR-0017, 0018, 0019).
- **File size: no `.dart` file over 300 lines** (CI `tool/ci/file_length_check.dart`). Split by responsibility before you
  reach it (ADR-0014).
- **Code that reads as written by a careful person (ADR-0014):**
  1. Comments say why, never what. No comments that narrate history (`// S-12 stub`, `// moved from v1`), cite docs
     (`// §10.2`, `// D4`, `// FR-31`) or restate the code. Requirement IDs go in test names.
  2. `///` docs only on public API, and only when they add a unit, range, lifecycle or failure rule the name does not say.
  3. `// TODO(owner): action` only, linked to a story on the board.
  4. No unused interfaces, one-method helper classes, defensive `try/catch` that rethrows, or asserts that restate types.
  5. Extract a well-named function instead of writing a comment over a block. Aim for functions ≤ 40 lines,
     early returns, `switch` expressions on sealed types, no `default` on sealed/enum switches.
  6. No commented-out code, no `print`; logging through `CrashReporter.log`.
  7. One word per idea across the codebase; tests named as behaviours, arrange / act / assert.
- **Coverage and TDD (ADR-0020):** red → green → refactor; every bug fix starts with a failing test. 100 % line coverage of
  `lib/` (exclusions E1–E4 only, no other `coverage:ignore`). Tests must assert behaviour, not just run lines.
- **Lints (ADR-0021):** `flutter analyze --fatal-infos` clean with the shared `analysis_rules.yaml`; `dart format` clean.
- **Checks you run:**
  - `dart analyze <your files>` or `flutter analyze --fatal-infos <your files>`;
  - `dart run tool/ci/file_length_check.dart` (from `stock_pulse/`) once your files exist;
  - only your own tests: `dart test test/<your tests>` in `market_server`, `flutter test test/<your tests>` in `stock_pulse`.

  Others' half-done files may break a full-project run; that is expected mid-wave. The manager runs the full suite at the wave checkpoint.
- Do not run `flutter pub upgrade`. Run `flutter pub get` / `dart pub get` only if your story changes a pubspec you own.
- Do not commit, push, or edit anything under `docs/` except a short note in your LLD if you had to deviate (say why).

## Report to the dashboard (required)
Every Bash call starts with:
`export TEAM_DIR=docs/team; T=tools/agent-team/scripts/team.py`
- When you start a story: `python3 $T task <S-id> in_progress --owner <you>` and `python3 $T agent <you> working --activity "<S-id>: <what>"`. Update the activity at each step ("writing tests", "implementing X", "fixing analyze").
- Post 1–3 real messages per story in `--thread build`: a decision you made, a deviation from the LLD, or something another developer must know (`--to` them).
- When the story's tests pass and analyze is clean on your files: `python3 $T task <S-id> review --owner <you> --note "<n> tests pass; files: ..."`. Never mark `done` (the dev lead does that after checking).
- If blocked: `python3 $T task <S-id> blocked --owner <you> --note "<why>"` and post in `build`.
- At the end: `python3 $T agent <you> waiting --activity "<stories> in review"`.
- Never edit `events.jsonl` by hand; use `python3 $T retract --by <you>` to take back a message. No test messages. Avoid unescaped double quotes inside message text.

## Return to the manager (under 150 words)
Stories finished, tests added and passing (numbers you saw), files changed, any deviation from the LLD, anything blocked or needed from another developer.
