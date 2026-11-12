// Resizable panels and text size for the dashboard. Sizes are CSS variables
// on <html>, saved in localStorage so a reload keeps the user's layout.
(() => {
  const KEY = "agent-team-layout";
  const root = document.documentElement;
  const ZOOMS = [0.8, 0.9, 1, 1.1, 1.25, 1.4];
  const MIN = { col: 200, row: 220 };

  const load = () => {
    try { return JSON.parse(localStorage.getItem(KEY)) || {}; } catch { return {}; }
  };
  let saved = load();
  const save = () => localStorage.setItem(KEY, JSON.stringify(saved));

  const applyVars = () => {
    for (const [name, value] of Object.entries(saved.vars || {})) root.style.setProperty(name, value);
  };

  const applyZoom = () => {
    const zoom = saved.zoom || 1;
    document.body.style.zoom = zoom === 1 ? "" : String(zoom);
    document.getElementById("zoom-level").textContent = `${Math.round(zoom * 100)}%`;
  };

  const stepZoom = (dir) => {
    const current = ZOOMS.indexOf(saved.zoom || 1);
    const next = ZOOMS[Math.min(ZOOMS.length - 1, Math.max(0, (current < 0 ? 2 : current) + dir))];
    saved.zoom = next;
    save();
    applyZoom();
  };

  const setVar = (name, px) => {
    saved.vars = { ...(saved.vars || {}), [name]: `${Math.round(px)}px` };
    root.style.setProperty(name, saved.vars[name]);
  };

  const clearVar = (name) => {
    if (saved.vars) delete saved.vars[name];
    root.style.removeProperty(name);
    save();
  };

  // The panel a gutter resizes: the one before it for dir 1, after it for -1.
  // Row gutters resize the section above them.
  const targetOf = (gutter) => {
    if (gutter.classList.contains("row")) return gutter.previousElementSibling;
    return gutter.dataset.dir === "-1" ? gutter.nextElementSibling : gutter.previousElementSibling;
  };

  const startDrag = (event, gutter) => {
    if (event.button !== 0) return;
    event.preventDefault();
    const isRow = gutter.classList.contains("row");
    const target = targetOf(gutter);
    const dir = Number(gutter.dataset.dir || 1);
    const zoom = saved.zoom || 1;
    const start = isRow ? event.clientY : event.clientX;
    const startSize = isRow ? target.getBoundingClientRect().height : target.getBoundingClientRect().width;
    const grid = gutter.parentElement;
    // Leave the middle panel at least 320 px when widening a side column.
    const maxCol = grid.getBoundingClientRect().width - 320 - (getOthersWidth(gutter, target));

    gutter.classList.add("dragging");
    gutter.setPointerCapture(event.pointerId);
    document.body.classList.add("resizing");
    document.body.classList.toggle("rows", isRow);

    const move = (e) => {
      const delta = ((isRow ? e.clientY : e.clientX) - start) * dir;
      const size = (startSize + delta) / zoom;
      if (isRow) setVar(gutter.dataset.var, Math.max(MIN.row, size));
      else setVar(gutter.dataset.var, Math.min(maxCol / zoom, Math.max(MIN.col, size)));
    };
    const end = () => {
      gutter.classList.remove("dragging");
      document.body.classList.remove("resizing", "rows");
      gutter.removeEventListener("pointermove", move);
      save();
    };
    gutter.addEventListener("pointermove", move);
    gutter.addEventListener("pointerup", end, { once: true });
    gutter.addEventListener("pointercancel", end, { once: true });
  };

  // Width already taken by the other side column in the same row.
  const getOthersWidth = (gutter, target) => {
    const panels = [...gutter.parentElement.children].filter((el) => el.classList.contains("panel"));
    const sides = [panels[0], panels[panels.length - 1]].filter((el) => el && el !== target);
    return sides.reduce((sum, el) => sum + el.getBoundingClientRect().width, 0);
  };

  // Arrow keys nudge a focused gutter, so resizing works without a mouse.
  const nudge = (event, gutter) => {
    const isRow = gutter.classList.contains("row");
    const keys = isRow ? { ArrowUp: -1, ArrowDown: 1 } : { ArrowLeft: -1, ArrowRight: 1 };
    if (!(event.key in keys)) return;
    event.preventDefault();
    const target = targetOf(gutter);
    const rect = target.getBoundingClientRect();
    const size = (isRow ? rect.height : rect.width) / (saved.zoom || 1);
    const step = (event.shiftKey ? 80 : 20) * keys[event.key] * Number(gutter.dataset.dir || 1);
    setVar(gutter.dataset.var, Math.max(isRow ? MIN.row : MIN.col, size + step));
    save();
  };

  document.addEventListener("DOMContentLoaded", () => {
    applyVars();
    applyZoom();
    for (const gutter of document.querySelectorAll(".gutter")) {
      gutter.tabIndex = 0;
      gutter.setAttribute("role", "separator");
      gutter.setAttribute("aria-orientation", gutter.classList.contains("row") ? "horizontal" : "vertical");
      gutter.addEventListener("pointerdown", (e) => startDrag(e, gutter));
      gutter.addEventListener("dblclick", () => clearVar(gutter.dataset.var));
      gutter.addEventListener("keydown", (e) => nudge(e, gutter));
    }
    document.getElementById("zoom-in").addEventListener("click", () => stepZoom(1));
    document.getElementById("zoom-out").addEventListener("click", () => stepZoom(-1));
    document.getElementById("layout-reset").addEventListener("click", () => {
      for (const name of Object.keys(saved.vars || {})) root.style.removeProperty(name);
      saved = {};
      save();
      applyZoom();
    });
  });
})();
