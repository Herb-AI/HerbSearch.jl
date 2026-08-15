# Turns an `Inspection` into a single self-contained HTML page.

function _rule_label(rule)::String
    if rule isa Expr
        if rule.head === :call && !isempty(rule.args)
            return string(rule.args[1])
        end
        s = string(rule)
        return length(s) > 24 ? s[1:nextind(s, 0, 24)] * "…" : s
    end
    return string(rule)
end

function _grammar_payload(grammar::AbstractGrammar)
    entries = Vector{Any}()
    for i ∈ eachindex(grammar.rules)
        push!(entries, Dict{String,Any}(
            "index" => i,
            "type" => string(grammar.types[i]),
            "label" => _rule_label(grammar.rules[i]),
            "text" => string(grammar.types[i]) * " = " * string(grammar.rules[i]),
            "terminal" => grammar.isterminal[i],
        ))
    end
    return entries
end

_payload(::Nothing) = nothing

function _payload(snapshot::NodeSnapshot)
    return Dict{String,Any}(
        "rule" => snapshot.rule,
        "domain" => snapshot.domain,
        "hole" => snapshot.ishole,
        "uniform" => snapshot.isuniform,
        "children" => Any[_payload(c) for c ∈ snapshot.children],
    )
end

function _payload(change::NodeChange)
    return Dict{String,Any}(
        "path" => change.path,
        "kind" => string(change.kind),
        "removed" => change.removed,
        "added" => change.added,
    )
end

function _payload(entry::QueueEntry)
    return Dict{String,Any}(
        "kind" => entry.kind,
        "priority" => entry.priority,
        "tree" => _payload(entry.tree),
        "feasible" => entry.feasible,
        "info" => entry.info,
    )
end

function _payload(step::SearchStep)
    return Dict{String,Any}(
        "index" => step.index,
        "expr" => step.expr,
        "program" => _payload(step.program),
        "queue" => Any[_payload(q) for q ∈ step.queue],
        "firstEvent" => step.first_event,
        "lastEvent" => step.last_event,
    )
end

function _payload(event::TraceEvent, index::Int)
    return Dict{String,Any}(
        "i" => index,
        "kind" => string(event.kind),
        "solver" => string(event.solver),
        "name" => event.name,
        "detail" => event.detail,
        "path" => event.path,
        "parent" => event.parent,
        "depth" => event.depth,
        "step" => event.step,
        "before" => _payload(event.before),
        "after" => _payload(event.after),
        "feasibleBefore" => event.feasible_before,
        "feasibleAfter" => event.feasible_after,
        "changes" => Any[_payload(c) for c ∈ event.changes],
    )
end

function _payload(insp::Inspection)
    grammar = insp.grammar
    return Dict{String,Any}(
        "title" => insp.title,
        "exhausted" => insp.exhausted,
        "rules" => _grammar_payload(grammar),
        "constraints" => Any[string(c) for c ∈ grammar.constraints],
        "steps" => Any[_payload(s) for s ∈ insp.steps],
        "events" => Any[_payload(e, i) for (i, e) ∈ enumerate(insp.trace.events)],
    )
end

"""
    write_html(insp::Inspection, file::AbstractString) -> String

Write the interactive inspector for `insp` to `file` and return the path.
The page is completely self-contained (no network access, no dependencies).
"""
function write_html(insp::Inspection, file::AbstractString)
    html = replace(_HTML_TEMPLATE, "/*__DATA__*/" => to_json(_payload(insp)))
    Base.open(file, "w") do io
        write(io, html)
    end
    insp.file = String(file)
    return insp.file
end

const _HTML_TEMPLATE = raw"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Herb inspector</title>
<style>
:root {
  --bg: #14161a; --panel: #1c1f26; --panel2: #232733; --line: #3a4152;
  --fg: #e6e9ef; --muted: #99a1b3; --accent: #6ea8fe; --good: #5ecf8d;
  --bad: #ff7b72; --warn: #e3b341; --hole: #2c3448;
}
* { box-sizing: border-box; }
body { margin: 0; font: 13px/1.45 ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
       background: var(--bg); color: var(--fg); }
header { padding: 10px 16px; border-bottom: 1px solid var(--line); background: var(--panel);
         display: flex; align-items: center; gap: 16px; flex-wrap: wrap; }
h1 { font-size: 15px; margin: 0; font-weight: 600; }
.sub { color: var(--muted); font-size: 12px; }
.tabs { display: flex; gap: 4px; margin-left: auto; }
.tab { padding: 5px 12px; border: 1px solid var(--line); border-radius: 6px; cursor: pointer;
       background: var(--panel2); color: var(--muted); user-select: none; }
.tab.active { background: var(--accent); color: #10131a; border-color: var(--accent); font-weight: 600; }
label.chk { display: inline-flex; align-items: center; gap: 6px; cursor: pointer; color: var(--muted); }
main { display: none; }
main.active { display: grid; grid-template-columns: 320px 1fr; height: calc(100vh - 47px); }
.side { border-right: 1px solid var(--line); overflow: auto; background: var(--panel); }
.content { overflow: auto; padding: 16px; }
.list-item { padding: 7px 12px; border-bottom: 1px solid #262b36; cursor: pointer; }
.list-item:hover { background: var(--panel2); }
.list-item.sel { background: #2b3550; border-left: 3px solid var(--accent); padding-left: 9px; }
.list-item .mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; }
.badge { display: inline-block; padding: 0 6px; border-radius: 4px; font-size: 10.5px;
         background: var(--panel2); border: 1px solid var(--line); color: var(--muted); }
.badge.prop { border-color: #4a6fa8; color: #9fc2ff; }
.badge.post { border-color: #6b579c; color: #c3aef5; }
.badge.manip { border-color: #4f7a5b; color: #9fe0b6; }
.badge.state { border-color: #7a6a3f; color: #e6cd8a; }
.badge.bad { border-color: #8a4340; color: var(--bad); }
.toolbar { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; margin-bottom: 12px; }
button { background: var(--panel2); color: var(--fg); border: 1px solid var(--line);
         border-radius: 6px; padding: 5px 11px; cursor: pointer; font-size: 13px; }
button:hover:not(:disabled) { border-color: var(--accent); }
button:disabled { opacity: .4; cursor: default; }
.card { background: var(--panel); border: 1px solid var(--line); border-radius: 8px;
        padding: 12px 14px; margin-bottom: 14px; }
.card h2 { font-size: 12px; text-transform: uppercase; letter-spacing: .06em; color: var(--muted);
           margin: 0 0 8px; font-weight: 600; }
.mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
table { border-collapse: collapse; width: 100%; font-size: 12px; }
th, td { text-align: left; padding: 4px 8px; border-bottom: 1px solid #262b36; }
th { color: var(--muted); font-weight: 600; }
.empty { color: var(--muted); padding: 24px; text-align: center; }

/* ---- tree ---- */
.tree { overflow: auto; padding: 8px 4px 16px; }
.tree ul { position: relative; padding: 20px 0 0 0; margin: 0; display: flex; justify-content: center; list-style: none; }
.tree li { position: relative; padding: 20px 8px 0 8px; display: flex; flex-direction: column; align-items: center; list-style: none; }
.tree li::before, .tree li::after { content: ''; position: absolute; top: 0; right: 50%;
  border-top: 1px solid var(--line); width: 50%; height: 20px; }
.tree li::after { right: auto; left: 50%; border-left: 1px solid var(--line); }
.tree li:only-child::after, .tree li:only-child::before { display: none; }
.tree li:only-child { padding-top: 0; }
.tree li:first-child::before, .tree li:last-child::after { border: 0 none; }
.tree li:last-child::before { border-right: 1px solid var(--line); border-radius: 0 6px 0 0; }
.tree li:first-child::after { border-radius: 6px 0 0 0; }
.tree > ul { padding-top: 0; }
.tree > ul > li { padding-top: 0; }
.tree > ul > li::before, .tree > ul > li::after { display: none; }
.tree ul ul::before { content: ''; position: absolute; top: 0; left: 50%;
  border-left: 1px solid var(--line); width: 0; height: 20px; }
.node { border: 1px solid var(--line); background: var(--panel2); border-radius: 6px;
        padding: 4px 9px; white-space: nowrap; font-family: ui-monospace, Menlo, monospace;
        font-size: 12.5px; position: relative; }
.node.hole { background: var(--hole); border-style: dashed; }
.node .dom { color: var(--muted); font-size: 11px; }
.node .chip { display: inline-block; padding: 0 4px; margin: 0 1px; border-radius: 3px;
              background: #38415a; color: #cdd6ea; }
.node.chg { border-color: var(--warn); box-shadow: 0 0 0 2px rgba(227,179,65,.25); }
.node.fill { border-color: var(--good); box-shadow: 0 0 0 2px rgba(94,207,141,.25); }
.node.shape { border-color: var(--accent); box-shadow: 0 0 0 2px rgba(110,168,254,.25); }
.node.anchor::after { content: '⟵ constraint'; position: absolute; left: calc(100% + 6px); top: 3px;
  font-size: 10.5px; color: var(--warn); font-family: ui-sans-serif, system-ui; white-space: nowrap; }
.rm { color: var(--bad); } .add { color: var(--good); }
.legend { color: var(--muted); font-size: 11.5px; display: flex; gap: 14px; flex-wrap: wrap; }
.legend span::before { content: '■ '; }
</style>
</head>
<body>
<header>
  <h1 id="title">Herb inspector</h1>
  <div class="sub" id="subtitle"></div>
  <label class="chk"><input type="checkbox" id="primitives" checked> show grammar primitives</label>
  <div class="tabs">
    <div class="tab active" data-tab="programs">Programs</div>
    <div class="tab" data-tab="search">Search queue</div>
    <div class="tab" data-tab="propagation">Propagation</div>
    <div class="tab" data-tab="grammar">Grammar</div>
  </div>
</header>

<main id="programs" class="active">
  <div class="side" id="programList"></div>
  <div class="content" id="programView"></div>
</main>

<main id="search">
  <div class="side" id="queueList"></div>
  <div class="content" id="queueView"></div>
</main>

<main id="propagation">
  <div class="side" id="eventList"></div>
  <div class="content" id="eventView"></div>
</main>

<main id="grammar">
  <div class="side" id="grammarSide"></div>
  <div class="content" id="grammarView"></div>
</main>

<script>
const DATA = /*__DATA__*/;
const RULES = DATA.rules;
const EVENTS = DATA.events;
const STEPS = DATA.steps;

const state = { primitives: true, program: 0, step: 0, queueItem: 0, event: 0,
                onlyProps: true, hideNoop: false, showBefore: false };

const $ = (id) => document.getElementById(id);
function el(tag, cls, text) {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text !== undefined) n.textContent = text;
  return n;
}
function ruleOf(i) { return RULES[i - 1]; }
function ruleLabel(i) {
  const r = ruleOf(i);
  if (!r) return String(i);
  return state.primitives ? r.label : String(i);
}
function ruleTitle(i) { const r = ruleOf(i); return r ? r.text : ('rule ' + i); }
function pathKey(p) { return p.join('.'); }
function pathText(p) { return p.length ? '[' + p.join(', ') + ']' : '[] (root)'; }

/* ---------------- tree rendering ---------------- */
function renderTree(snap, marks, anchor) {
  const wrap = el('div', 'tree');
  if (!snap) { wrap.appendChild(el('div', 'empty', 'no tree')); return wrap; }
  const ul = el('ul');
  ul.appendChild(renderNode(snap, [], marks || {}, anchor ? pathKey(anchor) : null));
  wrap.appendChild(ul);
  return wrap;
}
function renderNode(snap, path, marks, anchorKey) {
  const li = el('li');
  const key = pathKey(path);
  const node = el('div', 'node' + (snap.hole ? ' hole' : ''));
  const mark = marks[key];
  if (mark) node.classList.add(mark === 'fill' ? 'fill' : mark === 'shape' ? 'shape' : 'chg');
  if (anchorKey !== null && key === anchorKey) node.classList.add('anchor');

  if (!snap.hole || snap.domain.length === 1) {
    const rule = snap.rule || snap.domain[0];
    node.appendChild(el('span', '', ruleLabel(rule)));
    node.title = ruleTitle(rule) + '   at ' + pathText(path);
    if (snap.hole) node.title += '  (filled hole)';
  } else {
    const holder = el('span', 'dom');
    if (snap.domain.length > 10) {
      holder.appendChild(el('span', '', '{' + snap.domain.length + ' rules}'));
      node.title = snap.domain.map(r => ruleTitle(r)).join('\n');
    } else {
      snap.domain.forEach((r, i) => {
        const c = el('span', 'chip', ruleLabel(r));
        c.title = ruleTitle(r);
        holder.appendChild(c);
      });
    }
    node.appendChild(holder);
    if (!node.title) node.title = 'hole at ' + pathText(path);
  }
  li.appendChild(node);
  if (snap.children.length) {
    const ul = el('ul');
    snap.children.forEach((c, i) => ul.appendChild(renderNode(c, path.concat([i + 1]), marks, anchorKey)));
    li.appendChild(ul);
  }
  return li;
}
function marksOf(changes) {
  const m = {};
  (changes || []).forEach(c => { m[pathKey(c.path)] = c.kind; });
  return m;
}
function legend() {
  const d = el('div', 'legend');
  d.innerHTML = '<span style="color:var(--warn)">domain reduced</span>' +
                '<span style="color:var(--good)">hole filled</span>' +
                '<span style="color:var(--accent)">shape changed</span>';
  return d;
}

/* ---------------- tab: programs ---------------- */
function drawPrograms() {
  const side = $('programList'); side.innerHTML = '';
  if (!STEPS.length) { side.appendChild(el('div', 'empty', 'no programs were emitted')); }
  STEPS.forEach((s, i) => {
    const item = el('div', 'list-item' + (i === state.program ? ' sel' : ''));
    item.appendChild(el('div', 'mono', '#' + s.index + '  ' + s.expr));
    item.onclick = () => { state.program = i; drawPrograms(); };
    side.appendChild(item);
  });
  const view = $('programView'); view.innerHTML = '';
  const s = STEPS[state.program];
  if (!s) { view.appendChild(el('div', 'empty', 'nothing to show')); return; }
  const card = el('div', 'card');
  card.appendChild(el('h2', '', 'program #' + s.index));
  card.appendChild(el('div', 'mono', s.expr));
  view.appendChild(card);
  const tc = el('div', 'card');
  tc.appendChild(el('h2', '', 'abstract syntax tree'));
  tc.appendChild(renderTree(s.program, {}, null));
  view.appendChild(tc);
}

/* ---------------- tab: search queue ---------------- */
function drawSearch() {
  const side = $('queueList'); side.innerHTML = '';
  STEPS.forEach((s, i) => {
    const item = el('div', 'list-item' + (i === state.step ? ' sel' : ''));
    item.appendChild(el('div', 'mono', 'step ' + s.index + ' · ' + s.expr));
    const n = s.lastEvent - s.firstEvent + 1;
    item.appendChild(el('div', 'sub', s.queue.length + ' in queue · ' + (n > 0 ? n : 0) + ' solver events'));
    item.onclick = () => { state.step = i; state.queueItem = 0; drawSearch(); };
    side.appendChild(item);
  });
  const view = $('queueView'); view.innerHTML = '';
  const s = STEPS[state.step];
  if (!s) { view.appendChild(el('div', 'empty', 'nothing to show')); return; }

  const bar = el('div', 'toolbar');
  const prev = el('button', '', '◀ previous step');
  prev.disabled = state.step === 0;
  prev.onclick = () => { state.step--; state.queueItem = 0; drawSearch(); };
  const next = el('button', '', 'next step ▶');
  next.disabled = state.step >= STEPS.length - 1;
  next.onclick = () => { state.step++; state.queueItem = 0; drawSearch(); };
  bar.appendChild(prev); bar.appendChild(next);
  bar.appendChild(el('div', 'sub', 'step ' + s.index + ' of ' + STEPS.length +
    ' — queue state right after this program was emitted'));
  view.appendChild(bar);

  const qc = el('div', 'card');
  qc.appendChild(el('h2', '', 'queue (' + s.queue.length + ' items, lowest priority first)'));
  if (!s.queue.length) qc.appendChild(el('div', 'sub', 'the queue is empty'));
  s.queue.forEach((q, i) => {
    const row = el('div', 'list-item' + (i === state.queueItem ? ' sel' : ''));
    const head = el('div');
    head.appendChild(el('span', 'badge ' + (q.kind === 'UniformIterator' ? 'post' : 'prop'), q.kind));
    head.appendChild(el('span', '', ' priority ' + q.priority + (i === 0 ? '  ← next to be popped' : '')));
    if (!q.feasible) head.appendChild(el('span', 'badge bad', 'infeasible'));
    row.appendChild(head);
    row.appendChild(el('div', 'sub', q.info));
    row.onclick = () => { state.queueItem = i; drawSearch(); };
    qc.appendChild(row);
  });
  view.appendChild(qc);

  const q = s.queue[state.queueItem];
  if (q) {
    const tc = el('div', 'card');
    tc.appendChild(el('h2', '', 'queue item ' + (state.queueItem + 1) + ' · ' + q.kind));
    tc.appendChild(el('div', 'sub', q.kind === 'UniformIterator'
      ? 'a uniform (fixed shape) tree; the uniform solver enumerates its remaining assignments'
      : 'a generic solver state; it still contains non-uniform holes to branch on'));
    tc.appendChild(renderTree(q.tree, {}, null));
    view.appendChild(tc);
  }

  const ev = EVENTS.filter(e => e.step === s.index);
  const ec = el('div', 'card');
  ec.appendChild(el('h2', '', 'solver events during this step (' + ev.length + ')'));
  if (!ev.length) ec.appendChild(el('div', 'sub', 'none'));
  ev.slice(0, 200).forEach(e => {
    const row = el('div', 'list-item');
    row.appendChild(eventSummary(e));
    row.onclick = () => { showTab('propagation'); state.onlyProps = false; selectEvent(e.i); };
    ec.appendChild(row);
  });
  view.appendChild(ec);
}

/* ---------------- tab: propagation ---------------- */
function badgeClass(kind) {
  return kind === 'propagate' ? 'prop' : kind === 'post' ? 'post'
       : kind === 'manipulate' ? 'manip' : 'state';
}
function eventSummary(e) {
  const d = el('div');
  d.style.paddingLeft = (e.depth * 12) + 'px';
  const line = el('div');
  line.appendChild(el('span', 'badge ' + badgeClass(e.kind), e.kind));
  line.appendChild(el('span', 'mono', ' ' + e.name));
  if (e.changes.length) line.appendChild(el('span', 'badge', e.changes.length + ' change' + (e.changes.length > 1 ? 's' : '')));
  if (!e.feasibleAfter && e.feasibleBefore) line.appendChild(el('span', 'badge bad', 'infeasible'));
  d.appendChild(line);
  d.appendChild(el('div', 'sub mono', (e.path.length ? 'at ' + pathText(e.path) + ' · ' : '') + e.detail));
  return d;
}
function visibleEvents() {
  return EVENTS.filter(e => {
    if (state.onlyProps && e.kind !== 'propagate' && e.kind !== 'post') return false;
    if (state.hideNoop && e.changes.length === 0) return false;
    return true;
  });
}
function selectEvent(i) { state.event = i; state.showBefore = false; drawPropagation(); }
// keep the selection on an event that is actually visible under the current filters
function snapSelection() {
  const list = visibleEvents();
  if (!list.length || list.some(e => e.i === state.event)) return;
  const after = list.find(e => e.i >= state.event);
  state.event = (after || list[list.length - 1]).i;
}

function drawPropagation() {
  snapSelection();
  const list = visibleEvents();
  const side = $('eventList'); side.innerHTML = '';
  const filters = el('div', 'card');
  const f1 = el('label', 'chk'); const c1 = el('input'); c1.type = 'checkbox'; c1.checked = state.onlyProps;
  c1.onchange = () => { state.onlyProps = c1.checked; drawPropagation(); };
  f1.appendChild(c1); f1.appendChild(el('span', '', 'only constraint propagations'));
  const f2 = el('label', 'chk'); const c2 = el('input'); c2.type = 'checkbox'; c2.checked = state.hideNoop;
  c2.onchange = () => { state.hideNoop = c2.checked; drawPropagation(); };
  f2.appendChild(c2); f2.appendChild(el('span', '', 'hide events without changes'));
  filters.appendChild(f1); filters.appendChild(el('div')); filters.appendChild(f2);
  side.appendChild(filters);

  if (!list.length) side.appendChild(el('div', 'empty', 'no events recorded'));
  list.forEach(e => {
    const item = el('div', 'list-item' + (e.i === state.event ? ' sel' : ''));
    item.appendChild(el('div', 'sub', 'step ' + e.step + ' · #' + e.i + ' · ' + e.solver + ' solver'));
    item.appendChild(eventSummary(e));
    item.onclick = () => selectEvent(e.i);
    side.appendChild(item);
  });

  const view = $('eventView'); view.innerHTML = '';
  const e = EVENTS[state.event - 1];
  if (!e) { view.appendChild(el('div', 'empty', 'select an event on the left')); return; }

  const pos = list.findIndex(x => x.i === e.i);
  const bar = el('div', 'toolbar');
  const back = el('button', '', '◀ revert');
  back.title = 'go back to the previous propagation';
  back.disabled = pos <= 0;
  back.onclick = () => selectEvent(list[pos - 1].i);
  const fwd = el('button', '', 'apply next ▶');
  fwd.disabled = pos < 0 || pos >= list.length - 1;
  fwd.onclick = () => selectEvent(list[pos + 1].i);
  bar.appendChild(back); bar.appendChild(fwd);
  const tgl = el('button', '', state.showBefore ? 'showing: before' : 'showing: after');
  tgl.onclick = () => { state.showBefore = !state.showBefore; drawPropagation(); };
  bar.appendChild(tgl);
  bar.appendChild(el('div', 'sub', (pos + 1) + ' / ' + list.length + '  ·  event #' + e.i + ' of step ' + e.step));
  view.appendChild(bar);

  const head = el('div', 'card');
  head.appendChild(el('h2', '', e.kind + ' · ' + e.solver + ' solver'));
  const t = el('div', 'mono'); t.textContent = e.detail || e.name; head.appendChild(t);
  head.appendChild(el('div', 'sub', 'applied at path ' + pathText(e.path)));
  if (!e.feasibleAfter && e.feasibleBefore)
    head.appendChild(el('div', 'sub', '⚠ this event made the state infeasible — the search backtracks'));
  view.appendChild(head);

  const ch = el('div', 'card');
  ch.appendChild(el('h2', '', 'deductions (' + e.changes.length + ')'));
  if (!e.changes.length) {
    ch.appendChild(el('div', 'sub', 'this propagation did not change the tree'));
  } else {
    const tb = el('table');
    const hr = el('tr');
    ['node', 'what', 'rules removed', 'rules added'].forEach(h => hr.appendChild(el('th', '', h)));
    tb.appendChild(hr);
    e.changes.forEach(c => {
      const r = el('tr');
      r.appendChild(el('td', 'mono', pathText(c.path)));
      r.appendChild(el('td', '', c.kind === 'fill' ? 'hole filled' : c.kind === 'shape' ? 'subtree replaced' : 'domain reduced'));
      const rm = el('td', 'mono rm', c.removed.map(x => ruleLabel(x)).join(', '));
      rm.title = c.removed.map(x => ruleTitle(x)).join('\n');
      r.appendChild(rm);
      r.appendChild(el('td', 'mono add', c.added.map(x => ruleLabel(x)).join(', ')));
      tb.appendChild(r);
    });
    ch.appendChild(tb);
  }
  view.appendChild(ch);

  const tc = el('div', 'card');
  tc.appendChild(el('h2', '', state.showBefore ? 'tree before this event' : 'tree after this event'));
  tc.appendChild(legend());
  tc.appendChild(renderTree(state.showBefore ? e.before : e.after, marksOf(e.changes), e.path));
  view.appendChild(tc);
}

/* ---------------- tab: grammar ---------------- */
function drawGrammar() {
  const side = $('grammarSide'); side.innerHTML = '';
  const c = el('div', 'card');
  c.appendChild(el('h2', '', 'constraints (' + DATA.constraints.length + ')'));
  if (!DATA.constraints.length) c.appendChild(el('div', 'sub', 'the grammar has no constraints'));
  DATA.constraints.forEach(x => c.appendChild(el('div', 'mono', x)));
  side.appendChild(c);

  const view = $('grammarView'); view.innerHTML = '';
  const card = el('div', 'card');
  card.appendChild(el('h2', '', 'rules'));
  const tb = el('table');
  const hr = el('tr');
  ['#', 'type', 'primitive', 'rule'].forEach(h => hr.appendChild(el('th', '', h)));
  tb.appendChild(hr);
  RULES.forEach(r => {
    const tr = el('tr');
    tr.appendChild(el('td', 'mono', String(r.index)));
    tr.appendChild(el('td', 'mono', r.type));
    tr.appendChild(el('td', 'mono', r.label));
    tr.appendChild(el('td', 'mono', r.text));
    tb.appendChild(tr);
  });
  card.appendChild(tb);
  view.appendChild(card);
}

/* ---------------- wiring ---------------- */
function drawAll() { drawPrograms(); drawSearch(); drawPropagation(); drawGrammar(); }
function showTab(name) {
  document.querySelectorAll('main').forEach(m => m.classList.toggle('active', m.id === name));
  document.querySelectorAll('.tab').forEach(t => t.classList.toggle('active', t.dataset.tab === name));
}
document.querySelectorAll('.tab').forEach(t => t.onclick = () => showTab(t.dataset.tab));
$('primitives').onchange = (ev) => { state.primitives = ev.target.checked; drawAll(); };
document.addEventListener('keydown', (ev) => {
  if (!$('propagation').classList.contains('active')) return;
  const list = visibleEvents();
  const pos = list.findIndex(x => x.i === state.event);
  if (ev.key === 'ArrowLeft' && pos > 0) selectEvent(list[pos - 1].i);
  if (ev.key === 'ArrowRight' && pos >= 0 && pos < list.length - 1) selectEvent(list[pos + 1].i);
});

$('title').textContent = DATA.title;
$('subtitle').textContent = STEPS.length + ' program(s)' + (DATA.exhausted ? ' (iterator exhausted)' : '') +
  ' · ' + EVENTS.length + ' solver event(s) · ' + RULES.length + ' rules · ' +
  DATA.constraints.length + ' constraint(s)';
const firstProp = EVENTS.find(e => e.kind === 'propagate' || e.kind === 'post');
state.event = firstProp ? firstProp.i : (EVENTS.length ? 1 : 0);
drawAll();
</script>
</body>
</html>
"""
