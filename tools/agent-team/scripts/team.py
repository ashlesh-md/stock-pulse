#!/usr/bin/env python3
"""Agent team pipeline log and dashboard server (Python stdlib only).

Every agent writes events to <dir>/events.jsonl through this script. The
dashboard rebuilds the current state from those events, so there is no shared
JSON file for agents to overwrite.

  team.py init --dir D --name "Project" [--root R]
  team.py --dir D phase PHASE STATUS [--note TEXT]
  team.py --dir D agent NAME STATUS [--activity TEXT]
  team.py --dir D task ID STATUS [--title T] [--owner A] [--story S] [--note N]
  team.py --dir D say --from A [--to B] [--thread T] TEXT
  team.py --dir D signoff GATE DECISION --by A [--notes TEXT]
  team.py --dir D artifact NAME PATH --by A
  team.py --dir D log --by A TEXT
  team.py --dir D retract --by A    # hide A's last message (never edit events.jsonl)
  team.py --dir D status            # print a text summary
  team.py serve [--port 8095]       # dashboard for every registered project

Statuses
  phase:   pending | in_progress | blocked | done
  agent:   idle | working | waiting | done
  task:    todo | in_progress | review | done | blocked | dropped (hidden; use when a story is split or removed)
  signoff: pending | approved | changes_requested
"""

from __future__ import annotations

import argparse
import fcntl
import json
import mimetypes
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

HOME = Path.home() / ".claude" / "agent-team"
REGISTRY = HOME / "projects.json"
DASHBOARD = Path(__file__).resolve().parent.parent / "dashboard"

PHASE_STATUS = {"pending", "in_progress", "blocked", "done"}
AGENT_STATUS = {"idle", "working", "waiting", "done"}
TASK_STATUS = {"todo", "in_progress", "review", "done", "blocked", "dropped"}
SIGNOFF = {"pending", "approved", "changes_requested"}

DEFAULT_PHASES = [
    {"id": "intake", "name": "Intake", "owner": "manager"},
    {"id": "discovery", "name": "Discovery", "owner": "analyst"},
    {"id": "prd", "name": "PRD", "owner": "product-manager"},
    {"id": "design", "name": "UX design", "owner": "ux-designer"},
    {"id": "gate-1", "name": "Gate 1: scope", "owner": "you", "gate": True},
    {"id": "architecture", "name": "TRD / HLD / LLD", "owner": "architect"},
    {"id": "planning", "name": "Stories", "owner": "scrum-master"},
    {"id": "gate-2", "name": "Gate 2: plan", "owner": "you", "gate": True},
    {"id": "build", "name": "Build", "owner": "dev-lead"},
    {"id": "qa", "name": "QA", "owner": "qa-lead"},
    {"id": "review", "name": "Code review", "owner": "reviewer"},
    {"id": "gate-3", "name": "Gate 3: release", "owner": "you", "gate": True},
]

DEFAULT_SIGNOFFS = [
    {"id": "product", "name": "Product", "owner": "product-manager"},
    {"id": "design", "name": "Design / UX", "owner": "ux-designer"},
    {"id": "engineering", "name": "Engineering", "owner": "reviewer"},
    {"id": "qa", "name": "QA", "owner": "qa-lead"},
    {"id": "user", "name": "You", "owner": "you"},
]

DEFAULT_ROSTER = [
    {"id": "manager", "name": "Engineering manager", "team": "lead"},
    {"id": "analyst", "name": "Business analyst", "team": "product"},
    {"id": "product-manager", "name": "Product manager", "team": "product"},
    {"id": "ux-designer", "name": "UX designer", "team": "design"},
    {"id": "ui-designer", "name": "Visual designer", "team": "design"},
    {"id": "architect", "name": "Architect", "team": "dev"},
    {"id": "scrum-master", "name": "Scrum master", "team": "product"},
    {"id": "dev-lead", "name": "Dev lead", "team": "dev"},
    {"id": "dev-realtime", "name": "Dev: realtime and server", "team": "dev"},
    {"id": "dev-trading", "name": "Dev: trading screens", "team": "dev"},
    {"id": "dev-ai", "name": "Dev: AI chat and charts", "team": "dev"},
    {"id": "dev-perf", "name": "Dev: startup and performance", "team": "dev"},
    {"id": "qa-lead", "name": "QA lead", "team": "qa"},
    {"id": "qa-automation", "name": "QA automation", "team": "qa"},
    {"id": "reviewer", "name": "Code reviewer", "team": "review"},
]


# ---------------------------------------------------------------- storage

def now_ms() -> int:
    return int(time.time() * 1000)


def read_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def registry() -> list[dict]:
    return read_json(REGISTRY, [])


def register(project: dict) -> None:
    HOME.mkdir(parents=True, exist_ok=True)
    items = [p for p in registry() if p["dir"] != project["dir"]]
    items.append(project)
    REGISTRY.write_text(json.dumps(items, indent=2))


def append_event(team_dir: Path, event: dict) -> None:
    if not (team_dir / "team.json").exists():
        sys.exit(f"No team.json in {team_dir}. Run: team.py init --dir {team_dir} --name ...")
    event = {"ts": now_ms(), **event}
    line = json.dumps(event, ensure_ascii=False) + "\n"
    with open(team_dir / "events.jsonl", "a", encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write(line)
        fcntl.flock(f, fcntl.LOCK_UN)


def read_events(team_dir: Path) -> list[dict]:
    path = team_dir / "events.jsonl"
    if not path.exists():
        return []
    events = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                continue  # a half-written line never breaks the dashboard
    return events


# ---------------------------------------------------------------- state

def build_state(team_dir: Path) -> dict:
    """Fold the event log into the current pipeline state."""
    config = read_json(team_dir / "team.json", {})
    phases = {p["id"]: {**p, "status": "pending", "note": "", "updated": None}
              for p in config.get("phases", [])}
    signoffs = {s["id"]: {**s, "decision": "pending", "by": None, "notes": "", "updated": None,
                          "history": []} for s in config.get("signoffs", [])}
    agents = {a["id"]: {**a, "status": "idle", "activity": "", "updated": None, "events": 0}
              for a in config.get("roster", [])}
    tasks: dict[str, dict] = {}
    messages, artifacts, timeline = [], {}, []

    def touch_agent(name: str | None, ts: int, activity: str | None = None):
        if not name or name == "you":
            return
        a = agents.setdefault(name, {"id": name, "name": name, "team": "other", "status": "idle",
                                     "activity": "", "updated": None, "events": 0})
        a["updated"] = ts
        a["events"] += 1
        if activity:
            a["activity"] = activity

    for e in read_events(team_dir):
        kind, ts = e.get("type"), e.get("ts")
        if kind == "phase":
            p = phases.setdefault(e["phase"], {"id": e["phase"], "name": e["phase"], "owner": ""})
            p.update(status=e["status"], note=e.get("note", ""), updated=ts)
            if e["status"] == "in_progress" and not p.get("started"):
                p["started"] = ts
            if e["status"] == "done":
                p["finished"] = ts
            timeline.append({"ts": ts, "who": e.get("by", "manager"),
                             "text": f"Phase {p['name']}: {e['status']}" + (f" ({p['note']})" if p["note"] else "")})
        elif kind == "agent":
            touch_agent(e["agent"], ts, e.get("activity"))
            agents[e["agent"]]["status"] = e["status"]
        elif kind == "task":
            t = tasks.setdefault(e["id"], {"id": e["id"], "title": e["id"], "owner": "", "story": "",
                                           "note": "", "status": "todo", "created": ts})
            for key in ("title", "owner", "story", "note"):
                if e.get(key):
                    t[key] = e[key]
            t["status"], t["updated"] = e["status"], ts
            touch_agent(t["owner"], ts)
            timeline.append({"ts": ts, "who": t["owner"] or "manager",
                             "text": f"{t['id']} {t['title']} → {e['status']}"})
        elif kind == "retract":
            for i in range(len(messages) - 1, -1, -1):
                if messages[i]["from"] == e["by"]:
                    messages.pop(i)
                    break
        elif kind == "message":
            messages.append({"ts": ts, "from": e["from"], "to": e.get("to"),
                             "thread": e.get("thread") or "general", "text": e["text"]})
            touch_agent(e["from"], ts)
        elif kind == "signoff":
            s = signoffs.setdefault(e["gate"], {"id": e["gate"], "name": e["gate"], "owner": e["by"],
                                                "history": []})
            s.update(decision=e["decision"], by=e["by"], notes=e.get("notes", ""), updated=ts)
            s["history"].append({"ts": ts, "by": e["by"], "decision": e["decision"],
                                 "notes": e.get("notes", "")})
            touch_agent(e["by"], ts)
            timeline.append({"ts": ts, "who": e["by"],
                             "text": f"Sign-off {s['name']}: {e['decision']}"})
        elif kind == "artifact":
            artifacts[e["path"]] = {"name": e["name"], "path": e["path"], "by": e["by"], "ts": ts}
            touch_agent(e["by"], ts)
            timeline.append({"ts": ts, "who": e["by"], "text": f"Wrote {e['name']}"})
        elif kind == "log":
            touch_agent(e["by"], ts, e["text"])
            timeline.append({"ts": ts, "who": e["by"], "text": e["text"]})

    phase_list = list(phases.values())
    done = sum(1 for p in phase_list if p["status"] == "done")
    current = next((p for p in phase_list if p["status"] in ("in_progress", "blocked")), None)
    task_list = sorted((t for t in tasks.values() if t["status"] != "dropped"),
                       key=lambda t: t.get("created") or 0)
    tasks_done = sum(1 for t in task_list if t["status"] == "done")
    progress = (done / len(phase_list)) if phase_list else 0
    if current and current["id"] == "build" and task_list:
        progress += (tasks_done / len(task_list)) / len(phase_list)

    return {
        "name": config.get("name", team_dir.name),
        "dir": str(team_dir),
        "root": config.get("root"),
        "phases": phase_list,
        "current": current["id"] if current else None,
        "progress": round(progress, 4),
        "signoffs": list(signoffs.values()),
        "agents": list(agents.values()),
        "tasks": task_list,
        "messages": messages[-400:],
        "artifacts": sorted(artifacts.values(), key=lambda a: a["ts"]),
        "timeline": timeline[-300:][::-1],
        "updated": max([e.get("ts", 0) for e in read_events(team_dir)] or [0]),
    }


# ---------------------------------------------------------------- server

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def send_json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("cache-control", "no-store")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def project_dir(self, query) -> Path | None:
        wanted = (query.get("project") or [None])[0]
        projects = registry()
        for p in projects:
            if wanted in (None, p["id"]):
                return Path(p["dir"])
        return None

    def do_GET(self):
        url = urlparse(self.path)
        query = parse_qs(url.query)
        if url.path == "/api/projects":
            out = []
            for p in registry():
                d = Path(p["dir"])
                if (d / "team.json").exists():
                    s = build_state(d)
                    out.append({"id": p["id"], "name": s["name"], "progress": s["progress"],
                                "current": s["current"], "updated": s["updated"]})
            out.sort(key=lambda p: p["updated"] or 0, reverse=True)
            return self.send_json(out)
        if url.path == "/api/state":
            d = self.project_dir(query)
            if not d:
                return self.send_json({"error": "unknown project"}, 404)
            return self.send_json(build_state(d))
        if url.path == "/api/artifact":
            d = self.project_dir(query)
            rel = (query.get("path") or [""])[0]
            if not d or not rel:
                return self.send_json({"error": "missing"}, 400)
            root = Path(read_json(d / "team.json", {}).get("root") or d).resolve()
            target = (root / rel).resolve()
            if root not in target.parents and target != root:
                return self.send_json({"error": "outside project"}, 403)
            if not target.is_file():
                return self.send_json({"error": "not found"}, 404)
            return self.send_json({"path": rel, "text": target.read_text(encoding="utf-8", errors="replace")[:400_000]})
        # static dashboard files
        name = "index.html" if url.path in ("/", "") else url.path.lstrip("/")
        file = (DASHBOARD / name).resolve()
        if DASHBOARD not in file.parents or not file.is_file():
            self.send_response(404)
            self.end_headers()
            return
        body = file.read_bytes()
        self.send_response(200)
        self.send_header("content-type", (mimetypes.guess_type(file.name)[0] or "text/plain") + "; charset=utf-8")
        self.send_header("cache-control", "no-store")
        self.end_headers()
        self.wfile.write(body)


# ---------------------------------------------------------------- CLI

def summary(state: dict) -> str:
    lines = [f"{state['name']}  ·  {round(state['progress'] * 100)}%  ·  current: {state['current'] or '-'}"]
    lines.append("Phases: " + "  ".join(f"{p['id']}={p['status']}" for p in state["phases"]))
    lines.append("Sign-offs: " + "  ".join(f"{s['id']}={s['decision']}" for s in state["signoffs"]))
    busy = [a for a in state["agents"] if a["status"] == "working"]
    lines.append("Working: " + (", ".join(f"{a['id']} ({a['activity']})" for a in busy) or "nobody"))
    if state["tasks"]:
        counts: dict[str, int] = {}
        for t in state["tasks"]:
            counts[t["status"]] = counts.get(t["status"], 0) + 1
        lines.append("Tasks: " + "  ".join(f"{k}={v}" for k, v in counts.items()))
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", default=os.environ.get("TEAM_DIR"), help="team folder (holds team.json)")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--dir", default=argparse.SUPPRESS, help="team folder (holds team.json)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    _add = sub.add_parser
    sub.add_parser = lambda *x, **k: _add(*x, parents=[common], **k)

    p = sub.add_parser("init"); p.add_argument("--name", required=True); p.add_argument("--root")
    p.add_argument("--id")

    p = sub.add_parser("phase"); p.add_argument("phase"); p.add_argument("status", choices=sorted(PHASE_STATUS))
    p.add_argument("--note", default=""); p.add_argument("--by", default="manager")

    p = sub.add_parser("agent"); p.add_argument("name"); p.add_argument("status", choices=sorted(AGENT_STATUS))
    p.add_argument("--activity", default="")

    p = sub.add_parser("task"); p.add_argument("id"); p.add_argument("status", choices=sorted(TASK_STATUS))
    for f in ("title", "owner", "story", "note"):
        p.add_argument(f"--{f}", default="")

    p = sub.add_parser("say"); p.add_argument("--from", dest="sender", required=True)
    p.add_argument("--to", default=None); p.add_argument("--thread", default="general"); p.add_argument("text")

    p = sub.add_parser("signoff"); p.add_argument("gate"); p.add_argument("decision", choices=sorted(SIGNOFF))
    p.add_argument("--by", required=True); p.add_argument("--notes", default="")

    p = sub.add_parser("artifact"); p.add_argument("name"); p.add_argument("path"); p.add_argument("--by", required=True)

    p = sub.add_parser("log"); p.add_argument("--by", required=True); p.add_argument("text")

    p = sub.add_parser("retract"); p.add_argument("--by", required=True)

    sub.add_parser("status")

    p = sub.add_parser("serve"); p.add_argument("--port", type=int, default=8095)

    a = ap.parse_args(argv)

    if a.cmd == "serve":
        server = ThreadingHTTPServer(("127.0.0.1", a.port), Handler)
        print(f"Agent team dashboard: http://localhost:{a.port}")
        server.serve_forever()
        return

    if not a.dir:
        sys.exit("Pass --dir or set TEAM_DIR")
    team_dir = Path(a.dir).expanduser().resolve()

    if a.cmd == "init":
        team_dir.mkdir(parents=True, exist_ok=True)
        cfg_path = team_dir / "team.json"
        if not cfg_path.exists():
            cfg = {"name": a.name, "root": str(Path(a.root).expanduser().resolve()) if a.root else str(team_dir),
                   "phases": DEFAULT_PHASES, "signoffs": DEFAULT_SIGNOFFS, "roster": DEFAULT_ROSTER}
            cfg_path.write_text(json.dumps(cfg, indent=2))
        project_id = a.id or "".join(c if c.isalnum() else "-" for c in a.name.lower()).strip("-")
        register({"id": project_id, "dir": str(team_dir)})
        print(f"Team ready in {team_dir} (project id: {project_id})")
        return

    ev = {
        "phase": lambda: {"type": "phase", "phase": a.phase, "status": a.status, "note": a.note, "by": a.by},
        "agent": lambda: {"type": "agent", "agent": a.name, "status": a.status, "activity": a.activity},
        "task": lambda: {"type": "task", "id": a.id, "status": a.status, "title": a.title,
                         "owner": a.owner, "story": a.story, "note": a.note},
        "say": lambda: {"type": "message", "from": a.sender, "to": a.to, "thread": a.thread, "text": a.text},
        "signoff": lambda: {"type": "signoff", "gate": a.gate, "decision": a.decision, "by": a.by, "notes": a.notes},
        "artifact": lambda: {"type": "artifact", "name": a.name, "path": a.path, "by": a.by},
        "log": lambda: {"type": "log", "by": a.by, "text": a.text},
        "retract": lambda: {"type": "retract", "by": a.by},
    }
    if a.cmd == "status":
        print(summary(build_state(team_dir)))
        return
    if a.cmd == "say" and (len(a.text.strip()) < 15 or a.text.strip().lower() in {"test", "noop", "placeholder", "ping"}):
        sys.exit("Refused: say needs a real message (15+ characters). Do not post test messages.")
    append_event(team_dir, ev[a.cmd]())
    print("ok")


if __name__ == "__main__":
    main()
