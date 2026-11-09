// Agent team dashboard: polls /api/state every 2 seconds and redraws.
const $ = (id) => document.getElementById(id);
const TEAM_COLORS = {
  lead: "var(--lead)", product: "var(--product)", design: "var(--design)",
  dev: "var(--dev)", qa: "var(--qa)", review: "var(--review)", other: "var(--other)",
};
const TEAM_NAMES = {
  lead: "Lead", product: "Product", design: "Design", dev: "Development",
  qa: "QA", review: "Review", other: "Other",
};
const COLUMNS = [
  ["todo", "To do"], ["in_progress", "In progress"], ["review", "Review"],
  ["blocked", "Blocked"], ["done", "Done"],
];
const STEP_ICON = { done: "✓", in_progress: "●", blocked: "!", pending: "", waiting: "?" };

let project = new URLSearchParams(location.search).get("project");
let lastUpdated = -1;
let state = null;
let thread = "all";
let agentFilter = null;

const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

function ago(ts) {
  if (!ts) return "never";
  const s = Math.max(0, Math.round((Date.now() - ts) / 1000));
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.round(s / 60)}m ago`;
  if (s < 86400) return `${Math.round(s / 3600)}h ago`;
  return `${Math.round(s / 86400)}d ago`;
}
const clock = (ts) => new Date(ts).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

function agentInfo(id) {
  const a = state?.agents.find((x) => x.id === id);
  return a || { id, name: id, team: id === "you" ? "lead" : "other" };
}
function initials(name) {
  return name.replace(/^Dev: /, "D ").split(/[\s:/-]+/).filter(Boolean).slice(0, 2)
    .map((w) => w[0].toUpperCase()).join("");
}
function avatar(id, status) {
  const a = agentInfo(id);
  const color = TEAM_COLORS[a.team] || TEAM_COLORS.other;
  const dot = status ? `<span class="st ${esc(status)}"></span>` : "";
  return `<div class="avatar" style="background:${color}" title="${esc(a.name)}">${esc(initials(a.name))}${dot}</div>`;
}

// ------------------------------------------------------------ renderers

function renderHeader() {
  $("project-name").textContent = state.name;
  document.title = `${state.name} · Agent Team`;
  const pct = Math.round(state.progress * 100);
  $("progress-bar").style.width = `${pct}%`;
  $("progress-text").textContent = `${pct}% complete`;
  const cur = state.phases.find((p) => p.id === state.current);
  $("current-phase").textContent = cur ? `now: ${cur.name}` : (pct === 100 ? "finished" : "waiting to start");
}

function renderPipeline() {
  $("pipeline").innerHTML = state.phases.map((p) => {
    // A gate whose phase is in progress is waiting on a person, not working.
    const status = p.gate && p.status === "in_progress" ? "waiting" : p.status;
    return `<li class="step ${esc(status)} ${p.gate ? "gate" : ""}" title="${esc(p.note)}">
      <div class="node"><span>${STEP_ICON[status] ?? ""}</span></div>
      <div class="step-name">${esc(p.name)}</div>
      <div class="step-owner">${esc(agentInfo(p.owner).name)}</div>
      ${p.note ? `<div class="step-note">${esc(p.note)}</div>` : ""}
    </li>`;
  }).join("");
}

function renderTeam() {
  const groups = {};
  for (const a of state.agents) (groups[a.team] ||= []).push(a);
  const order = ["lead", "product", "design", "dev", "qa", "review", "other"];
  const working = state.agents.filter((a) => a.status === "working").length;
  $("team-count").textContent = `${working} working · ${state.agents.length} total`;
  $("team").innerHTML = order.filter((t) => groups[t]).map((t) => `
    <div class="team-group">
      <div class="team-label" style="color:${TEAM_COLORS[t]}">${TEAM_NAMES[t]}</div>
      ${groups[t].map((a) => `
        <div class="agent ${agentFilter === a.id ? "selected" : ""}" data-agent="${esc(a.id)}">
          ${avatar(a.id, a.status)}
          <div style="min-width:0">
            <div class="agent-name">${esc(a.name)}</div>
            <div class="agent-act">${esc(a.activity || (a.status === "idle" ? "idle" : a.status))}${a.updated ? ` · ${ago(a.updated)}` : ""}</div>
          </div>
        </div>`).join("")}
    </div>`).join("");
  document.querySelectorAll(".agent").forEach((el) => el.onclick = () => {
    agentFilter = agentFilter === el.dataset.agent ? null : el.dataset.agent;
    renderTeam(); renderChat();
  });
}

function renderBoard() {
  const done = state.tasks.filter((t) => t.status === "done").length;
  $("task-count").textContent = state.tasks.length ? `${done}/${state.tasks.length} done` : "";
  $("board").innerHTML = COLUMNS.map(([key, label]) => {
    const cards = state.tasks.filter((t) => t.status === key)
      .filter((t) => !agentFilter || t.owner === agentFilter);
    return `<div class="col"><h3>${label}<span>${cards.length}</span></h3>
      ${cards.map((t) => {
        const a = agentInfo(t.owner);
        const color = TEAM_COLORS[a.team] || TEAM_COLORS.other;
        return `<div class="card" style="border-left-color:${color}">
          <div class="id">${esc(t.id)}${t.story ? ` · ${esc(t.story)}` : ""}</div>
          <div class="title">${esc(t.title)}</div>
          ${t.note ? `<div class="note">${esc(t.note)}</div>` : ""}
          ${t.owner ? `<span class="chip"><i style="background:${color}"></i>${esc(a.name)}</span>` : ""}
        </div>`;
      }).join("") || `<div class="empty">-</div>`}
    </div>`;
  }).join("");
}

function renderChat() {
  const threads = [...new Set(state.messages.map((m) => m.thread))];
  if (thread !== "all" && !threads.includes(thread)) thread = "all";
  $("threads").innerHTML = ["all", ...threads].map((t) =>
    `<button class="thread ${t === thread ? "active" : ""}" data-thread="${esc(t)}">${esc(t === "all" ? "All threads" : "#" + t)}</button>`).join("");
  document.querySelectorAll(".thread").forEach((b) => b.onclick = () => { thread = b.dataset.thread; renderChat(); });

  const msgs = state.messages
    .filter((m) => thread === "all" || m.thread === thread)
    .filter((m) => !agentFilter || m.from === agentFilter || m.to === agentFilter);
  $("msg-count").textContent = `${state.messages.length} messages`;
  const chat = $("chat");
  const atBottom = chat.scrollHeight - chat.scrollTop - chat.clientHeight < 40;
  chat.innerHTML = msgs.map((m) => `
    <div class="msg">
      ${avatar(m.from)}
      <div>
        <div class="msg-head"><b>${esc(agentInfo(m.from).name)}</b>
          ${m.to ? `<span class="to">→ ${esc(agentInfo(m.to).name)}</span>` : ""}
          ${thread === "all" ? `<span class="tag">#${esc(m.thread)}</span>` : ""}
          <time>${clock(m.ts)}</time></div>
        <div class="bubble">${esc(m.text)}</div>
      </div>
    </div>`).join("") || `<div class="empty">No discussion yet.</div>`;
  if (atBottom) chat.scrollTop = chat.scrollHeight;
}

function renderSignoffs() {
  const label = { pending: "Pending", approved: "Approved", changes_requested: "Changes requested" };
  $("signoffs").innerHTML = state.signoffs.map((s) => `
    <div class="so ${esc(s.decision)}">
      <div class="so-name">${esc(s.name)}</div>
      <div class="so-dec">${label[s.decision] || esc(s.decision)}</div>
      ${s.notes ? `<div class="so-notes">${esc(s.notes)}</div>` : ""}
      <div class="so-by">${s.by ? `${esc(agentInfo(s.by).name)} · ${ago(s.updated)}` : `owner: ${esc(agentInfo(s.owner).name)}`}
        ${s.history.length > 1 ? ` · ${s.history.length} rounds` : ""}</div>
    </div>`).join("");
}

function renderArtifacts() {
  $("artifacts").innerHTML = state.artifacts.slice().reverse().map((a) => `
    <li data-path="${esc(a.path)}" data-name="${esc(a.name)}">
      <div><div>${esc(a.name)}</div><div class="path">${esc(a.path)}</div></div>
      <div class="hint">${esc(agentInfo(a.by).name)}<br>${ago(a.ts)}</div>
    </li>`).join("") || `<li class="empty">No documents yet.</li>`;
  document.querySelectorAll(".artifacts li[data-path]").forEach((li) => li.onclick = () => openArtifact(li.dataset.path, li.dataset.name));
}

function renderTimeline() {
  $("timeline").innerHTML = state.timeline.slice(0, 120).map((t) => `
    <li><time>${clock(t.ts)}</time><div><span class="who">${esc(agentInfo(t.who).name)}:</span> ${esc(t.text)}</div></li>`).join("")
    || `<li class="empty">Nothing yet.</li>`;
}

// ------------------------------------------------------------ markdown viewer

function inline(s) {
  return esc(s)
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/(^|[^*])\*([^*]+)\*/g, "$1<em>$2</em>")
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="#" title="$2">$1</a>');
}
function markdown(src) {
  const lines = src.split("\n");
  let html = "", i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (line.startsWith("```")) {
      const body = [];
      for (i++; i < lines.length && !lines[i].startsWith("```"); i++) body.push(lines[i]);
      html += `<pre><code>${esc(body.join("\n"))}</code></pre>`; i++; continue;
    }
    const h = line.match(/^(#{1,4})\s+(.*)/);
    if (h) { html += `<h${h[1].length}>${inline(h[2])}</h${h[1].length}>`; i++; continue; }
    if (/^\s*\|/.test(line) && i + 1 < lines.length && /^\s*\|?\s*:?-{2,}/.test(lines[i + 1])) {
      const row = (l) => l.trim().replace(/^\||\|$/g, "").split("|").map((c) => c.trim());
      html += "<table><thead><tr>" + row(line).map((c) => `<th>${inline(c)}</th>`).join("") + "</tr></thead><tbody>";
      for (i += 2; i < lines.length && /^\s*\|/.test(lines[i]); i++)
        html += "<tr>" + row(lines[i]).map((c) => `<td>${inline(c)}</td>`).join("") + "</tr>";
      html += "</tbody></table>"; continue;
    }
    if (/^\s*([-*]|\d+\.)\s+/.test(line)) {
      const ordered = /^\s*\d+\./.test(line);
      html += ordered ? "<ol>" : "<ul>";
      for (; i < lines.length && /^\s*([-*]|\d+\.)\s+/.test(lines[i]); i++)
        html += `<li>${inline(lines[i].replace(/^\s*([-*]|\d+\.)\s+/, ""))}</li>`;
      html += ordered ? "</ol>" : "</ul>"; continue;
    }
    if (line.startsWith(">")) { html += `<blockquote>${inline(line.replace(/^>\s?/, ""))}</blockquote>`; i++; continue; }
    if (line.trim()) {
      const para = [];
      for (; i < lines.length && lines[i].trim() && !/^(#|```|\s*\||\s*[-*]\s|\s*\d+\.\s|>)/.test(lines[i]); i++) para.push(lines[i]);
      if (!para.length) { para.push(lines[i]); i++; }
      html += `<p>${inline(para.join(" "))}</p>`; continue;
    }
    i++;
  }
  return html;
}

async function openArtifact(path, name) {
  $("viewer-title").textContent = `${name} · ${path}`;
  $("viewer-body").innerHTML = "<p>Loading…</p>";
  $("viewer").showModal();
  try {
    const res = await fetch(`/api/artifact?project=${encodeURIComponent(project)}&path=${encodeURIComponent(path)}`);
    const data = await res.json();
    $("viewer-body").innerHTML = data.text != null
      ? (path.endsWith(".md") ? markdown(data.text) : `<pre><code>${esc(data.text)}</code></pre>`)
      : `<p>${esc(data.error)}</p>`;
  } catch (e) {
    $("viewer-body").innerHTML = `<p>Could not load: ${esc(e.message)}</p>`;
  }
}
$("viewer-close").onclick = () => $("viewer").close();

// ------------------------------------------------------------ polling

async function loadProjects() {
  const list = await (await fetch("/api/projects")).json();
  if (!project && list.length) project = list[0].id;
  $("project-select").innerHTML = list.map((p) =>
    `<option value="${esc(p.id)}" ${p.id === project ? "selected" : ""}>${esc(p.name)} (${Math.round(p.progress * 100)}%)</option>`).join("");
}
$("project-select").onchange = (e) => {
  project = e.target.value; lastUpdated = -1;
  history.replaceState(null, "", `?project=${encodeURIComponent(project)}`);
  tick();
};

async function tick() {
  try {
    if (!project) await loadProjects();
    const res = await fetch(`/api/state?project=${encodeURIComponent(project || "")}`);
    if (!res.ok) throw new Error(res.status);
    const next = await res.json();
    $("live-dot").className = "dot on";
    if (next.updated !== lastUpdated) {
      state = next; lastUpdated = next.updated;
      renderHeader(); renderPipeline(); renderTeam(); renderBoard();
      renderChat(); renderSignoffs(); renderArtifacts(); renderTimeline();
    }
    $("updated").textContent = `updated ${ago(state.updated)}`;
  } catch (e) {
    $("live-dot").className = "dot off";
    $("updated").textContent = "server offline";
  }
}

loadProjects().then(tick);
setInterval(tick, 2000);
setInterval(loadProjects, 15000);
