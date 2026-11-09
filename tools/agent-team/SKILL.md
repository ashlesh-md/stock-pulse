---
name: agent-team
description: Run a visible virtual software team (product, design, development, QA, review) as Claude Code subagents that discuss, split work into pieces, build, and give formal product, design, engineering and QA sign-offs, with a live mission-control dashboard showing every phase, agent, task, discussion thread and sign-off. Use when the user wants a team of agents to build an app or feature, wants agents to plan or debate together, wants sign-off gates, or asks to see the status of the team's pipeline. Builds on the build-app document pipeline.
---

# Agent Team

You are the **engineering manager**. You run the team, keep the event log honest, and stop at the user's gates. The documents each phase writes follow the `build-app` skill (brief, PRD, UX spec, TRD, HLD, LLD, stories, test plan, QA report). This skill adds four things: a **live dashboard**, **agent discussions**, **work split into tasks**, and **sign-offs**.

## 1. Setup (once per project)

```bash
T=tools/agent-team/scripts/team.py
python3 $T init --dir <repo>/docs/team --root <repo> --name "<Project>" --id <slug>
python3 $T serve --port 8095        # run in the background; one server shows every project
```

Open `http://localhost:8095` in the browser pane and tell the user the link. `team.json` holds the phases, gates, sign-offs and roster; edit it if the project needs different ones.

## 2. The event log (every agent uses it)

Agents never edit a shared state file. They append events, and the dashboard rebuilds state from them. In zsh, set `TEAM_DIR` instead of putting `--dir` in a variable.

| Event | Command |
|---|---|
| Agent status | `python3 $T agent <id> working --activity "Writing PRD section 4"` (`idle`/`working`/`waiting`/`done`) |
| Discussion | `python3 $T say --from <id> --to <id> --thread <topic> "message"` |
| Task | `python3 $T task <ID> in_progress --title "..." --owner <id> --story <S-n> --note "..."` (`todo`/`in_progress`/`review`/`done`/`blocked`; `dropped` hides a split or removed story) |
| Phase | `python3 $T phase <phase> in_progress --note "..."` (`pending`/`in_progress`/`blocked`/`done`) |
| Sign-off | `python3 $T signoff <gate> approved --by <id> --notes "..."` (`pending`/`approved`/`changes_requested`) |
| Document | `python3 $T artifact "PRD" docs/02-prd.md --by product-manager` (path relative to `--root`) |
| Note | `python3 $T log --by <id> "Ran 64 tests, all pass"` |
| Take back a message | `python3 $T retract --by <id>` (hides your last message) |
| Summary | `python3 $T status` |

## 3. Roster → subagent type

| Roster id | Team | Subagent |
|---|---|---|
| analyst | product | `analyst` |
| product-manager | product | `product-manager` |
| scrum-master | product | `scrum-master` (+ `product-owner` for acceptance criteria) |
| ux-designer, ui-designer | design | `ux-expert`, `ui-ux-designer` |
| architect | dev | `architect` |
| dev-lead, dev-* | dev | `flutter-expert` for app code, `backend-developer` for the Dart server |
| qa-lead, qa-automation | qa | `qa-engineer`, `test-automator` |
| reviewer | review | `code-reviewer` (+ the project's review skills, e.g. `flutter-code-review`, `flutter-architecture-review`) |

**Every agent must have Bash**, or its dashboard updates never run. `analyst`, `product-manager`, `ux-expert`, `architect` and `scrum-master` have no Bash. For those roles use `general-purpose` and paste the role's focus into the prompt (optionally the body of `~/.claude/agents/<role>.md`). `flutter-expert`, `ui-ux-designer`, `qa-engineer`, `test-automator`, `backend-developer` and `code-reviewer` have Bash. If an agent did run without Bash, log its messages from its report and add a `log` line saying so.

## 4. The brief every subagent gets

Subagents start cold. Every prompt contains:

1. **Who you are**: roster id, team, and one line of what this role cares about.
2. **What to read**: exact file paths (earlier docs, code folders).
3. **What to write**: exact output path and the sections it must have.
4. **How to report**: the `TEAM_DIR` export and the commands from §2, plus these rules:
   - set yourself `working` with a short activity when you start and on each major step, `done` at the end;
   - post 2–6 `say` messages in the phase thread: decisions, questions to other roles (use `--to`), disagreements;
   - register each document with `artifact`;
   - finish with your sign-off if you own one.
5. **Constraints**: the project's rules (style, no codegen, tests), and "do not commit or push".
6. **Return**: a summary under 200 words: what you wrote, open questions, risks.

## 5. Discussions: how agents think together

Real conversations run through the shared thread, in rounds. You start each round and pass the earlier messages and documents to the next agent.

**Design debate (architecture, risky features)**
1. *Propose*: 2–3 developer agents in parallel each write a short proposal to `docs/team/proposals/<topic>-<id>.md` and post a summary in `#<topic>`.
2. *Critique*: each reads the others' proposals and posts critiques (`--to` the author): risks, simpler options, what they'd take.
3. *Converge*: the architect (or dev lead) reads everything, writes the decision as an ADR, and posts it. Dissent stays recorded.

**Work breakdown (before build)**
1. The dev lead splits each story into tasks of about one file group or half a day, and logs them as `todo` with an owner.
2. Each owner reads its tasks and replies in `#planning` with concerns, missing pieces, or dependencies on another owner.
3. The dev lead resolves the dependencies and orders the tasks.

**Cross-role review**
- UX reviews screens and posts design feedback in `#design-review` (layout, one-handed reach, states, contrast, motion).
- QA reads acceptance criteria early and posts testability questions in `#qa`.
- The product manager answers scope questions in `#scope`.

Keep every message specific (names a screen, file, number or requirement). Do not post filler.

## 6. Build

- One developer agent per independent group of files; never two agents on the same files at once. Use parallel `Agent` calls when the groups don't touch.
- Each task: `in_progress` → code + tests (TDD) → `review` → reviewer or dev lead checks → `done`. A failed check moves it back to `in_progress` with a note.
- After each wave, you run analyze and the tests yourself and `log` the real numbers. Never log a result you did not see.

## 7. Sign-offs

Each sign-off owner checks against a written checklist and records `approved` or `changes_requested` with notes. Changes requested → the work goes back to its owner, then the signer checks again (the dashboard counts rounds).

| Sign-off | Owner | Checks |
|---|---|---|
| Product | product-manager | every Must FR is built and matches its acceptance criteria; nothing out of scope slipped in |
| Design / UX | ux-designer | screens match the UX spec; loading, empty, error, stale states; one-handed reach; contrast and text scale |
| Engineering | reviewer | architecture and code reviews have no open High findings; analyze clean; layering rules followed |
| QA | qa-lead | test plan run; every FR has a passing test; no open Critical or High defects; results attached |
| You | the user | only the user approves this; you record it after their yes in chat |

## 8. User gates

`gate-*` phases stop the pipeline. Set the gate `in_progress` (the dashboard shows it as waiting on the user), summarise what was produced in 3–6 bullets with doc links, and ask the user. Record their answer with `signoff user approved --by you` or `changes_requested`, then set the gate `done` and continue. If the user says "run autonomously", the agent sign-offs still happen but gates do not stop.

## 9. Honesty rules

- **Never edit or rewrite `events.jsonl`.** It is append-only; a rewrite can drop other agents' events written at the same moment. To correct a mistake, post a new `log` or `say` event saying what was wrong. Put this rule in every subagent brief.
- The dashboard is only as true as the log. Log failures, blocked tasks and changes requested as they happen.
- A subagent's report is a claim; check the files and run the tests before you mark work done.
- Never commit, push or deploy without the user's yes.
