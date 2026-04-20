
# PLAN — Feature-010 / Delivery-005: Editor Redesign

**Status:** Execution approved 2026-04-19.
**Branch:** `feature/editor-redesign` (from main post-PR#27 merge).
**Strategy:** Single delivery, one PR, draft-open-early for Copilot continuous review.

## Resolved blockers (from planning Q&A)

| # | Question | Resolution |
|---|---|---|
| Q1 | Font family | Inter (sans) + IBM Plex Mono |
| Q2 | Accent-bg opacity | 0.14 (runtime value, not :root 0.12) |
| Q3 | Orphan prop categories | All 11 current categories preserved |
| Q4 | Namespace | None — clean class names matching prototype, no backward compat |
| Q5 | Delivery scope | One delivery, all phases + all nice-to-haves, single PR |
| Q6 | CSS naming | No prefix, prototype names direct |
| Q7 | Rewrite latitude | Full shell rewrite allowed; inline CSS block deleted; preserve existing form logic |
| Q8 | `temp/Farhaven Editor/` | Delete at end, once redesign verified |
| Q9 | Commit granularity | Multiple small commits; Copilot re-reviews each push |
| Q10 | Nice-to-haves in scope | All of them (Cross-refs, Command Palette ⌘K, Status Bar, Hex preview, Playtest button, Tweaks panel) |
| Q11 | Map tab strategy | Full port of prototype map-editor layout + preserve all current tools/features |
| D1 | Anomaly tool | Skip — our model handles via `show_as_anomaly` flag on prop cap |
| D2 | Map action buttons | Menubar (File / Edit / View / Tools / Run / Help); right group: Command ⌘K, Undo, Redo, Save, Playtest |
| D3 | Minimap | Always ON |
| D4 | Prop palette | Vertical list (icon + name + ID) + category chips + search; no Origin dropdown in map palette |

---

Original plan saved below as produced by the Plan agent.

## Table of Contents

1. [Summary](#1-summary)
2. [Part A — Discovery Findings](#2-part-a--discovery-findings)
   - 2.1 Prototype Inventory
   - 2.2 Current Editor Inventory
   - 2.3 Token Scale (extracted from prototype)
   - 2.4 CSS Class Collision Audit
   - 2.5 Namespace Decision
   - 2.6 Test Surface Analysis
   - 2.7 SPEC Ambiguities Discovered
3. [Part B — Phased Plan](#3-part-b--phased-plan)
   - 3.1 Phase 1 — Tokens + Typography + Fonts
   - 3.2 Phase 2 — Sidebar Reorganization by Domain
   - 3.3 Phase 3 — Master-Detail Layout
   - 3.4 Phase 4 — Cross-Reference Panels
   - 3.5 Nice-to-Haves
4. [Part C — Phase 1 Pre-Flight](#4-part-c--phase-1-pre-flight)
   - 4.1 New file: `tools/level-editor/css/tokens.css`
   - 4.2 Edits to `index.html` (font links + CSS var replacements)
   - 4.3 Edits to JS inline-style literals
   - 4.4 Verification plan
5. [Part D — Branching + Merge Strategy](#5-part-d--branching--merge-strategy)
6. [Part E — Open Questions for Andre](#6-part-e--open-questions-for-andre)

---

## 1. Summary

The redesign ships in 4 incremental phases plus optional nice-to-haves. Each phase is runnable and rollback-able on its own. The prototype at `/home/andre/projects/Farhaven/temp/Farhaven Editor/` is the visual/IA spec; we reimplement in vanilla JS and preserve every module API in `tools/level-editor/js/*.js`. All 1168 unit asserts + 17 roundtrip tests currently pass against a mock DOM that ignores CSS classes, so Phase 1–2 carry near-zero test risk; Phase 3 has medium test risk only if module signatures change (they should not).

**Recommendation**: single feature branch with per-phase PRs merged into it, then a single squash to `main` at the end of each delivery. Reasoning in §5.

---

## 2. Part A — Discovery Findings

### 2.1 Prototype Inventory

Prototype lives at `/home/andre/projects/Farhaven/temp/Farhaven Editor/`.

| File | LoC | Purpose | Maps to our phase |
|---|---|---|---|
| `Editor.html` | 28 | React 18 + Babel UMD shell | Reference only |
| `editor.css` | 1392 | Full design system | **Phase 1 + 2 + 3 source** |
| `src/app.jsx` | 284 | `TitleBar`, `Sidebar`, `StatusBar`, `NAV`, tweaks state | **Phase 2** (sidebar/nav); nice-to-have (statusbar/tweaks/⌘K wiring) |
| `src/icons.jsx` | 59 | 13 inline SVG icons as pure strings (no React) | **Phase 2** (port verbatim) |
| `src/data.jsx` | 207 | Mock data (BIOMES, PROPS, EVENTS, RECIPES, etc.) + `SHOWCASE_MAP` | Reference only — we already have real data |
| `src/data-editors.jsx` | 560 | `BiomeEditor`, `PropEditor`, `RecipeEditor`, `EventsEditor`, `JournalEditor`, `CutsceneEditor`, `SettingsEditor` — all using master-detail shell | **Phase 3** (shell structure reference); cross-ref preview blocks inspire **Phase 4** |
| `src/hex-canvas.jsx` | 305 | SVG hex renderer | Out of scope (we use canvas, not SVG) |
| `src/map-editor.jsx` | 477 | Tool rail + left palette + canvas + right inspector | Reference for possible future map-tab visual polish |
| `src/command-palette.jsx` | 169 | ⌘K fuzzy-search palette | **Nice-to-have #1** |
| `src/tweaks.jsx` | 52 | Runtime accent/density toggle | **Nice-to-have #5** |

### 2.2 Current Editor Inventory

`/home/andre/projects/Farhaven/tools/level-editor/`:

- `index.html` — 1211 LoC (single file: CSS in `<style>` at top, markup in `<body>`)
  - CSS: lines 7–995
  - Body markup: lines 997–1210
- `server.py` — 11335 chars (dev server)
- `test-unit.mjs` — 1168 `assert(` calls across 218167 chars
- `test-dom-mocks.mjs` — trivial mock (lines 1–31), does NOT exercise CSS classes
- `test-roundtrip.mjs` — 17 tests for .tres roundtripping
- `verify-walls.mjs` — wall-serialization sanity check
- `js/` — 24 files, 20974 LoC total

Key JS modules and sizes:

| Module | LoC | Role |
|---|---|---|
| `js/app.js` | 1753 | App bootstrap, tab routing, save/load, toolbar wiring |
| `js/prop-editor.js` | 3845 | **Master-detail prop editor** — `PropDefModel`, cap editors, form builders |
| `js/biome-editor.js` | 1656 | **Master-detail biome editor** — `BiomeDataModel`, resource table, color picker |
| `js/canvas.js` | 1843 | Hex canvas rendering (2D context, not SVG) |
| `js/hex-grid.js` | 571 | Data model: `HexGrid`, `createTileData`, `CATEGORY_COLORS` (inline hex literals) |
| `js/hex-math.js` | 223 | Hex coordinate math |
| `js/tres-parser.js` | 755 | .tres read/write |
| `js/commands.js` | 626 | Undo/redo |
| `js/tools.js` | 497 | Paint/erase/select tool classes |
| `js/panels.js` | 944 | Modal/inline form scaffolding |
| `js/editor-common.js` | 158 | `renderGearHeader()` — 2-col header shared by prop/recipe/event |
| `js/recipe-editor.js` | 1529 | Recipe master-detail |
| `js/event-editor.js` | 1258 | Events master-detail |
| `js/journal-editor.js` | 793 | Journal master-detail |
| `js/cutscene-editor.js` | 780 | Cutscene master-detail |
| `js/settings-editor.js` | 334 | Game settings form |
| `js/file-discovery.js` | 476 | `ProjectContext`, `FileDiscovery`, `nextId` |
| `js/populate.js`, `map-generator.js`, `simplex-noise.js`, `validator.js`, `hex-textures.js`, `dirty-tracker.js`, `keyboard.js` | — | Support modules |

Existing sidebar/tab architecture:
- **Toolbar** (`index.html:1001–1005`): #toolbar with title + help button
- **Tab bar** (`index.html:1006–1025`): 18 flat `.tab-btn` buttons (settings, map, biomes, mineral, plant, animal, fungi, ooze, liquid, stuff, structure, equipment, vehicle, storage, recipes, events, journal, cutscenes). **Flat list = what Phase 2 replaces.**
- **Tab content** (`index.html:1026–1137`): 18 `.tab-panel` divs, only `#tab-map` has nested markup (map-sidebar + canvas + right sidebar). Others are placeholders populated by their editor modules.
- **Status bar** (`index.html:1138–1140`): minimal #status-bar with #status-text span.
- **Existing master-detail classes** (`index.html:368–516`): `.editor-split`, `.editor-list-panel`, `.editor-list-header`, `.editor-filter`, `.editor-new-btn`, `.editor-list-items`, `.editor-list-item`, `.editor-detail-panel`, `.editor-detail-header`, `.editor-detail-tabs`, `.editor-detail-tab`, `.editor-detail-body` — already in use for Biome/Prop/Recipe/etc. **Phase 3 replaces these with prototype classes mapped through our namespace.**

### 2.3 Token Scale (extracted from prototype `editor.css:5-55`)

Literal variables as they appear in the prototype `:root` block. These are the values we port in Phase 1.

```
Neutral graphite scale:
  --bg-0: #0f1014   (darkest — app background)
  --bg-1: #15171d   (panel)
  --bg-2: #1c1f27   (card / input)
  --bg-3: #262a35   (hover)
  --bg-4: #333847   (active)

Lines:
  --line:   #22252e  (hairline borders)
  --line-2: #2d313c  (stronger borders)

Text scale:
  --text-0: #e8eaf0   (primary)
  --text-1: #a5a9b5   (secondary)
  --text-2: #6d7280   (tertiary / labels)
  --text-3: #4a4e58   (disabled)

Accents:
  --amber:     #f4a261
  --amber-dim: #b97a47
  --amber-bg:  rgba(244, 162, 97, 0.12)
  --blue:      #5bb5e0
  --green:     #7ec886
  --red:       #e07b7b
  --gold:      #f0d060
  --violet:    #a88bd9

  --accent:    var(--amber)
  --accent-bg: var(--amber-bg)

Biome colors:
  --biome-crash:  #8b7355
  --biome-grass:  #66bf4d
  --biome-forest: #2d8b46
  --biome-rocky:  #9e8b78
  --biome-water:  #4a9bd9
  --biome-desert: #d4b269
  --biome-ash:    #4b4852
  --biome-tundra: #c8d2dc

Metrics:
  --radius: 4px
  --radius-lg: 6px
  --h-titlebar: 36px
  --h-tabs: 34px
  --h-status: 24px
  --w-tabrail: 52px

Fonts:
  --font-sans: 'IBM Plex Sans', ui-sans-serif, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif
  --font-mono: 'IBM Plex Mono', ui-monospace, 'SFMono-Regular', Menlo, monospace
```

**SPEC ambiguity found**: SPEC says "Fonts — `--font-sans` (IBM Plex Sans), `--font-mono` (IBM Plex Mono)" but `Editor.html:9` loads Google Fonts `Inter` + `IBM+Plex+Mono`, not Plex Sans. The CSS `--font-sans` string lists `'IBM Plex Sans'` first but nothing loads that family. The prototype renders in Inter because the font-family chain falls through to `ui-sans-serif`/system when Plex Sans isn't present. Andre's preamble explicitly says "Inter, IBM Plex Mono" — so Phase 1 `--font-sans` must be `'Inter', ui-sans-serif, …` and the Google Fonts link loads Inter + IBM Plex Mono. See §4 and §6 Q1.

Also note accent-bg opacity: the `:root` declaration is `rgba(244, 162, 97, 0.12)`, but `app.jsx:189` (runtime accent swap) uses `0.14`. Plan uses `0.14` (matches what the designer actually ships in runtime) and documents the override. See §6 Q2.

### 2.4 CSS Class Collision Audit

Audited against prototype class names that the SPEC mentions + all other semantic classes we'll introduce.

**Legend:** COLLISION = name exists in current `tools/level-editor/index.html` `<style>` block with a different definition. SAFE = no current definition.

| Prototype class | Current `index.html` definition (line) | Status |
|---|---|---|
| `.input` | — | SAFE |
| `.btn` | — | SAFE |
| `.btn.primary`, `.btn.danger` | — | SAFE |
| `.ctrl` | — | SAFE |
| `.row` | — | SAFE |
| `.section-title` | — | SAFE |
| `.master`, `.master-detail`, `.master-head`, `.master-list`, `.master-row` | — | SAFE |
| `.detail`, `.detail-head`, `.detail-body`, `.detail-form`, `.detail-preview` | — | SAFE |
| `.sidebar` | `#sidebar` (id, L749) — right-side hex-inspector rail in Map tab | **COLLISION** (id vs class, but both target a sidebar concept; rename prototype `.sidebar` → namespace) |
| `.sidebar-section`, `.sidebar-label` | L175, L181 (existing map-sidebar) | **COLLISION** |
| `.nav-item` | — | SAFE |
| `.search` | — | SAFE |
| `.num` | — | SAFE |
| `.slider-row` | — | SAFE |
| `.tag`, `.tag-strip` | — | SAFE |
| `.pill`, `.pill.dirty` | — | SAFE |
| `.count` | — | SAFE |
| `.badge` | — | SAFE |
| `.empty-state` | — | SAFE |
| `.toolbar` | `#toolbar` (L50, id) | **COLLISION** (id/class, but distinct selectors — still risky because prototype uses `.titlebar` so this is moot if we adopt prototype naming. However the prototype class list uses "titlebar" not "toolbar", so SAFE for class.) |
| `.titlebar`, `.titlebar-menu`, `.titlebar-spacer`, `.titlebar-right` | — | SAFE |
| `.statusbar` | `#status-bar` (L885, id) | **SOFT COLLISION** (class vs id). SAFE if we adopt `.statusbar` class. |
| `.tabs` | `#tabs` (L82, id) | **SOFT COLLISION** — same idea, but our `#tabs` targets an id. Class `.tabs` SAFE. |
| `.tab`, `.tab.active`, `.tab-icon`, `.tab-dirty` | `.tab-btn` (L89), `.tab-btn.active` (L107), `.tab-dirty` (L113), `.tab-panel` (L135) | **COLLISION on `.tab-dirty` + soft on `.tab`** — current uses `.tab-btn`; prototype uses `.tab`. If we keep both editors mounted during Phase 2 migration (legacy-nav fallback), the `.tab-dirty` dot style would conflict. See mitigation below. |
| `.panel`, `.panel-header`, `.panel-body` | — | SAFE |
| `.icon-btn` | — | SAFE |
| `.prop-grid` | L519 (label-input grid in gear form) | **COLLISION** — current `.prop-grid` is a 2-col label/input layout; prototype's `.prop-grid` (L403) is a 4-col prop palette grid for the map tab. Different semantics, same name. |
| `.prop-filter` | — | SAFE |
| `.prop-cell` | — | SAFE |
| `.prop-item`, `.prop-items` | — | SAFE |
| `.biome-swatch` | L275 (sidebar palette swatch) | **COLLISION** — both are 14–16px rounded swatches; semantically similar; styles overlap. Safe to unify since colors come from data. |
| `.color-swatch`, `.color-mini` | — | SAFE |
| `.rtable`, `.trow`, `.thead` | — | SAFE |
| `.cmdk-backdrop`, `.cmdk`, `.cmdk-input`, `.cmdk-list`, `.cmdk-item`, `.cmdk-section` | — | SAFE |
| `.tweaks`, `.tweaks-head`, `.tweaks-body`, `.tweak-row`, `.tweak-seg`, `.tweak-toggle` | — | SAFE |
| `.hex-tooltip` | — | SAFE |
| `.minimap`, `.mm-label`, `.mm-view` | — | SAFE |
| `.tool-btn`, `.tool-grid`, `.tool-group-header` | L224, L202, L189 | **COLLISION** (existing map-sidebar tool styling) |
| `.map-action-btn`, `.render-mode-btn`, `.elev-mode-btn` | L208, L331, L310 | SAFE (these aren't used in prototype) |
| `.prop-input`, `.prop-btn`, `.prop-btn-primary`, `.prop-btn-icon`, `.prop-card`, `.prop-hint`, `.prop-check`, `.prop-separator`, `.prop-full` | L550, L589, L602, L615, L632, L640, L578, L645, L651 | SAFE (not in prototype at all — these are our custom gear-form classes, stay intact) |
| `.editor-split`, `.editor-list-panel`, `.editor-list-header`, `.editor-list-items`, `.editor-list-item`, `.editor-detail-*`, `.editor-2col`, `.editor-gear-header`, `.editor-header-grid`, `.editor-field-wrap`, `.editor-btn-save`, `.editor-btn-delete` | L368–736 | **Legacy master-detail** — Phase 3 replaces these with prototype equivalents; delete when every editor migrates. |

**Confirmed collisions:** `.sidebar-section`, `.sidebar-label`, `.biome-swatch`, `.tool-btn`, `.tool-grid`, `.tool-group-header`, `.prop-grid`, `.tab-dirty`. Soft id-vs-class: `#sidebar`, `#tabs`, `#toolbar`, `#status-bar`.

### 2.5 Namespace Decision

**Recommendation: wrap in `.editor-v2` body class (Option B from SPEC), NOT `fh-` prefix.**

Justification:

1. **Smaller blast radius**: prefixing every prototype class (~120 of them) means touching every jsx-derived HTML string and every CSS line; a wrapper class is a single attribute on `<body>` and one extra selector in CSS (`.editor-v2 .input { … }` vs `.fh-input { … }`).
2. **Phase 1 runs outside the wrapper**: tokens (`:root { --bg-0 … }`) MUST be global because existing CSS already references CSS vars (`var(--accent)`, `var(--bg-primary)`, etc.) and we want to swap the *values* without duplicating scopes. Only component classes (Phase 2–3) need the wrapper.
3. **Clean rollback**: removing `document.body.classList.add('editor-v2')` disables all redesign markup fallback at once — zero-churn kill switch.
4. **Test isolation**: tests already run in a mock DOM that ignores `<body>` entirely. The wrapper doesn't change anything for them.
5. **Legacy-nav fallback for Phase 2**: easy to keep both navigations mounted while cutover runs — tabs live outside `.editor-v2`, sidebar lives inside, feature-flag chooses which is visible.

Trade-off: `fh-` prefix is arguably more explicit about "this is our design system"; wrapper is more pragmatic for a staged rollout. If we keep the redesign forever, we can do a follow-up `s/.editor-v2 //g` strip commit once the legacy is deleted.

**Collision mitigations under `.editor-v2` wrapper:**

| Collision | Mitigation |
|---|---|
| `.sidebar-section`, `.sidebar-label`, `.biome-swatch`, `.tool-btn`, `.tool-grid`, `.tool-group-header` | Phase 2 doesn't touch map tab's existing markup (map tab stays unchanged); Phase 2's new sidebar lives in `.editor-v2 .sidebar` (different ancestor); the legacy `.sidebar-section` selectors continue to apply to `#map-sidebar` descendants. **Zero conflict.** |
| `.prop-grid` (2-col label vs 4-col palette) | Prototype's `.prop-grid` only lives in map-tab left palette → rename prototype → `.prop-palette-grid` in our port (rename is trivial since the prototype JSX is not shipped). |
| `.tab-dirty` | Prototype `.tab-dirty` is a 5px amber dot on a `.tab`; current `.tab-dirty` is a 8px warning dot. Both scoped to tab bars that will be swapped wholesale in Phase 2 — pick one. Current tabs are deleted in Phase 2, so no runtime overlap. |
| `#sidebar`, `#tabs`, `#toolbar`, `#status-bar` id collisions | Phase 2 repurposes the shell: delete `#toolbar`/`#tabs` markup and replace with `.titlebar` + `.sidebar` (class). Keep `#sidebar` as the map-tab right rail (rename to `#map-hex-inspector` to free the name) or leave alone under `.editor-v2 .sidebar` scope — id-vs-class is different selector, CSS specificity wins class under wrapper. |

### 2.6 Test Surface Analysis

Tests that could break during migration:

| Test file | Exposure | Breaks if… |
|---|---|---|
| `test-dom-mocks.mjs` | Provides mock `document`. All queries return a fake element with `.classList`, `.style`, `.textContent`. | **Never** — the mock accepts any class/style mutation. |
| `test-unit.mjs` (1168 asserts) | Imports `PropDefModel`, `BiomeDataModel`, `TresParser`, `HexGrid`, `CommandHistory`, `KeyboardManager`, etc. Calls model methods, asserts model state. | Only breaks if we rename exports or change signatures of: `propModelToRaw`, `validatePropForm`, `biomeModelToRaw`, `BiomeDataModel` constructor, `RecipeModel`, `EventModel`, `JournalModel`, `CutsceneModel`, `PropDefModel`. **None of these should be touched in any phase.** |
| `test-roundtrip.mjs` (17 tests) | Parses and re-emits every `.tres` under `data/`. | Never — pure file I/O over Parser. Migration doesn't touch `tres-parser.js`. |
| `verify-walls.mjs` | Wall serialization roundtrip. | Never. |

**Conclusion**: zero test files touch CSS classes or computed styles. All phases can migrate freely if they preserve module exports. Flag any phase that changes JS module public API — none currently planned.

### 2.7 SPEC Ambiguities Discovered (defer to Andre)

- **A1 (fonts):** SPEC §"Phase 1 / Token categories" line 84 says `--font-sans` is "IBM Plex Sans", but `Editor.html:9` loads `Inter`. Andre's preamble says "Inter, IBM Plex Mono". **Plan uses Inter for sans**. Andre confirm.
- **A2 (accent-bg opacity):** `:root` has 0.12, runtime swap uses 0.14. Plan uses **0.14**. Andre confirm.
- **A3 (Maps badge):** SPEC `NAV` line 101 says `maps` has `badge: '<dirty_count>'`. Prototype `app.jsx:6` hardcodes `badge: 2`. We can compute this from `DirtyTracker.dirtyTabs.size` restricted to "map-ish" ids. Plan wires this; if count is 0, omit the badge.
- **A4 (Maps as master-detail?):** SPEC says Phase 3 applies master-detail to "Biome, Prop, Recipe, Journal, Cutscene, Settings" — does NOT explicitly say map tab gets redesigned. The prototype `map-editor.jsx` has a completely different layout (tool rail + left palette + canvas + right inspector). Plan **scopes Phase 3 to data editors only**; map tab gets a deferred Phase 3.5 decision.
- **A5 (category merger):** Current editor has 18 tabs (mineral/plant/animal/fungi/ooze/liquid/stuff/structure/equipment/vehicle/storage); prototype NAV only has 6 PROPS entries (plant/animal/mineral/structure/equipment/storage). Where do fungi/ooze/liquid/stuff/vehicle go? Options: (a) add them to NAV as extra items, (b) fold fungi/ooze under plant, liquid/stuff under mineral, vehicle under equipment. Plan defers to §6 Q3.
- **A6 (Recipe/Event/Journal/Cutscene counts):** Sidebar needs live counts. These require data to be loaded at app-boot. Current editor already loads these via `FileDiscovery`; plan relies on `ProjectContext` to expose counts.
- **A7 (delivery boundary):** SPEC tables at lines 207–217 map "delivery-005 = Phases 1–3" and "delivery-006 = Phase 4". User said delivery-005. **Plan treats Phases 1–3 as delivery-005**, Phase 4 as delivery-006, nice-to-haves as delivery-007. All phases can be individually shipped inside a delivery.

---

## 3. Part B — Phased Plan

### 3.1 Phase 1 — Tokens + Typography + Fonts

**Goal:** Visual refresh with zero structural changes. Editor looks 70% of the way to the prototype — new dark palette, Inter font, amber accent.

**Files:**

| Action | Path | Notes |
|---|---|---|
| CREATE | `tools/level-editor/css/tokens.css` | Full `:root` var block; see §4.1 for exact content |
| EDIT | `tools/level-editor/index.html` | (a) Add Google Fonts preconnect + Inter + Plex Mono `<link>` tags to `<head>`; (b) add `<link rel="stylesheet" href="css/tokens.css">`; (c) replace occurrences of hardcoded colors in `<style>` block with CSS vars; (d) replace legacy `--bg-primary/--text-primary` with aliases to new tokens so downstream code keeps working |
| EDIT | `tools/level-editor/js/hex-grid.js` | Line 79–88 — replace 10 inline hex literals in `CATEGORY_COLORS` with `getComputedStyle(document.documentElement).getPropertyValue('--…')` OR leave as-is but add token synonyms. **Defer to Phase 3**: canvas colors are render-perf sensitive; tokens in CSS don't help raw Canvas2D calls. Recommend keep literals but add comments mapping to tokens. |
| EDIT | `tools/level-editor/js/prop-editor.js:1004,1009,1894` | Replace `#4a1c1c`/`#7a3030`/`#ff9999` error-box hardcodes with vars `--bg-error`/`--line-error`/`--text-error` (new tokens under "State" section) |
| EDIT | `tools/level-editor/js/biome-editor.js:580` | Same error-box substitution |
| EDIT | `tools/level-editor/js/recipe-editor.js:996`, `event-editor.js:846`, `journal-editor.js:615`, `cutscene-editor.js:572`, `panels.js:169,193` | Same error-box substitution — 6 more call sites |
| EDIT | `tools/level-editor/js/canvas.js:11,17-20` | `BIOME_FALLBACK_COLOR`, `CANVAS_BG`, `CLIFF_COLOR`, `SELECTION_COLOR`, `SPAWN_COLOR` — optionally read from CSS vars at init time. **Defer to Phase 3** — same perf reason. |

**Deliverable (what "done" looks like):**
- Load `tools/level-editor/index.html` in browser. Font is Inter. Background is `#0f1014`, panels `#15171d`, text primary `#e8eaf0`. Accent on hover/active is amber `#f4a261`.
- Manual verification: take 4 screenshots (sidebar, map tab, prop editor, biome editor) and compare side-by-side to prototype screenshots.
- Test expectation: `node tools/level-editor/test-unit.mjs` → 1168/1168 pass. `node tools/level-editor/test-roundtrip.mjs` → 17/17 pass.

**Risk items + mitigation:**

| Risk | Mitigation |
|---|---|
| Google Fonts blocked on user's network | Font fallback chain covers this: `ui-sans-serif, -apple-system, …` |
| Color contrast regression (e.g. `--text-2 #6d7280` on `--bg-2 #1c1f27`) | Spot-check the 4 screenshots above. Contrast should be >= WCAG AA for primary text; secondary labels can be lower. |
| Existing CSS uses `var(--accent, #4a9eff)` at prop-editor L1004/1009 | Phase 1 replaces default-fallback hex with the new amber — side-effect `var(--accent)` resolves to `#f4a261` instead of blue. **This is intentional** (amber is the new accent). |
| Hex literals in `hex-grid.js:79-88` (CATEGORY_COLORS) don't use CSS vars | These render inside Canvas2D which doesn't read CSS — leave untouched in Phase 1. |

**Rollback:**
```
git revert <phase-1-commit-sha>    # single commit → single revert
```
OR hotfix: delete `<link rel="stylesheet" href="css/tokens.css">` line, delete the 2 Google Fonts `<link>` lines. Editor falls back to its old look. Total rollback time <30 seconds.

**Task decomposition (~2h chunks):**

- **P1-T1 (2h):** Write `css/tokens.css`; add font-link + stylesheet-link tags to `index.html`; do a full-replace of literal `#1e1e2e`, `#2a2a3c`, `#333348`, `#e0e0e8`, `#a0a0b0`, `#6ea8fe`, `#444460` etc. in the `<style>` block with vars. Add back-compat alias rules so `--bg-primary`/`--accent-hover` etc. still resolve. Browser-smoke-test.
- **P1-T2 (2h):** Replace the 6 error-box inline-CSS literals across editor JS files with new `--bg-error`/`--line-error`/`--text-error` tokens. Replace `prop-editor.js:1004,1009` `#4a9eff` fallback. Run unit tests. Manual verification screenshots.

### 3.2 Phase 2 — Sidebar Reorganization by Domain

**Goal:** Replace 18 flat tab buttons with a hierarchical domain-grouped sidebar (WORLD / PROPS / SYSTEMS / NARRATIVE / PROJECT).

**Files:**

| Action | Path | Notes |
|---|---|---|
| CREATE | `tools/level-editor/js/icons.js` | Port `temp/Farhaven Editor/src/icons.jsx` verbatim — strip JSX wrapper, expose `Icons.render(name, size)` returning an `<svg>` string; 13 icons: map, brush, bolt, leaf, paw, rocks, house, tool, box, flask, book, film, gear, plus, chev-r, search, save, undo, redo, play, git |
| CREATE | `tools/level-editor/js/sidebar.js` | New module. Exports `Sidebar` factory that takes `{ container, projectCtx, onRouteChange }` and renders the `<aside class="sidebar">` DOM tree. Uses `NAV` array (data-driven, like prototype `app.jsx:5-19`). |
| CREATE | `tools/level-editor/css/shell.css` | Shell-level styles: `.app-root`, `.main-row`, `.titlebar`, `.sidebar`, `.side-section`, `.side-header`, `.nav-item`, `.nav-item .count`, `.nav-item .badge`, `.main`, `.statusbar` (placeholder, nice-to-have). All selectors scoped under `.editor-v2` wrapper. Port from prototype `editor.css:1302-1388` + `:1202-1295` (titlebar). |
| EDIT | `tools/level-editor/index.html` | (a) Add `<link rel="stylesheet" href="css/shell.css">`; (b) Replace `<header id="toolbar">…</header><nav id="tabs">…</nav>` with new `<header class="titlebar">` + `<div class="main-row"><aside class="sidebar"></aside><main class="main"></main></div>` structure; (c) The 18 `<div class="tab-panel">` panels stay — they become `.main > .route-panel`, shown/hidden by JS based on route; (d) Add `<body class="editor-v2">` wrapper class |
| EDIT | `tools/level-editor/js/app.js` | (a) Replace `setupTabs()` with `setupSidebar()`; (b) Route registry maps NAV.id → panel DOM node; (c) `activateRoute(id)` hides siblings, shows target, updates sidebar active state; (d) `refreshSidebarCounts()` called after any data mutation to update the `.count` spans |

**NAV definition** (copy from SPEC § Phase 2, adjusted for current prop categories — defer category merger per §6 Q3):

```js
const NAV = [
  { id: 'map',       section: 'WORLD',     label: 'Maps',      icon: 'map',    badge: 'dirty' },
  { id: 'biomes',    section: 'WORLD',     label: 'Biomes',    icon: 'brush',  count: () => projectCtx.biomeCount() },
  { id: 'events',    section: 'WORLD',     label: 'Events',    icon: 'bolt',   count: () => projectCtx.eventCount() },
  { id: 'plant',     section: 'PROPS',     label: 'Flora',     icon: 'leaf',   count: () => projectCtx.propCount('plant') },
  { id: 'animal',    section: 'PROPS',     label: 'Fauna',     icon: 'paw',    count: () => projectCtx.propCount('animal') },
  { id: 'mineral',   section: 'PROPS',     label: 'Minerals',  icon: 'rocks',  count: () => projectCtx.propCount('mineral') },
  { id: 'structure', section: 'PROPS',     label: 'Structures',icon: 'house',  count: () => projectCtx.propCount('structure') },
  { id: 'equipment', section: 'PROPS',     label: 'Equipment', icon: 'tool',   count: () => projectCtx.propCount('equipment') },
  { id: 'storage',   section: 'PROPS',     label: 'Storage',   icon: 'box',    count: () => projectCtx.propCount('storage') },
  // ORPHAN CATEGORIES (pending §6 Q3): fungi, ooze, liquid, stuff, vehicle
  { id: 'recipes',   section: 'SYSTEMS',   label: 'Recipes',   icon: 'flask',  count: () => projectCtx.recipeCount() },
  { id: 'journal',   section: 'NARRATIVE', label: 'Journal',   icon: 'book',   count: () => projectCtx.journalCount() },
  { id: 'cutscenes', section: 'NARRATIVE', label: 'Cutscenes', icon: 'film',   count: () => projectCtx.cutsceneCount() },
  { id: 'settings',  section: 'PROJECT',   label: 'Settings',  icon: 'gear' },
];
```

**Deliverable:**
- Load editor. Left side is a 232px-wide sidebar grouped "WORLD, PROPS, SYSTEMS, NARRATIVE, PROJECT" with counts.
- Click any item — corresponding panel shows. Active item has amber left-border + `--accent-bg` tint.
- Top bar is now `.titlebar` (amber logo mark, "Editor" sub, chapter dropdown optional — defer until we have chapter switching).
- Keyboard routing (1, 2, 3, 4 keys?): out of scope for Phase 2. File → ⌘K palette (Phase 5).
- Screenshot: sidebar against prototype screenshot.
- Test expectation: unchanged 1168 unit + 17 roundtrip pass.

**Risk items + mitigation:**

| Risk | Mitigation |
|---|---|
| Routing logic in `app.js` changes break tab-specific init (e.g. biome editor's `show()` callback) | Audit every `setupTab(id, fn)` / `onTabActivated(id)` call during implementation. Route activation must call identical lifecycle hooks. |
| Sidebar count-refresh rate (recomputing 10 counts on every dirty change) | Cheap — `projectCtx` already caches; `O(1)` per count. Debounce to animation-frame if profiling shows cost. |
| Flat-tab users who have muscle memory for tab order | `NAV` order roughly mirrors tab order (map → biomes → PROPS → recipes → events → journal → cutscenes → settings). Document in release note. |
| Orphan categories (fungi/ooze/liquid/stuff/vehicle) have no NAV entry → unreachable | **BLOCKER** — must resolve §6 Q3 before shipping Phase 2. Temporary mitigation: keep legacy tab bar hidden-but-present with `.editor-v2 #tabs { display: none }`, toggle via query-string `?nav=legacy`. |

**Rollback:**
- `document.body.classList.remove('editor-v2')` + revert shell.css link → falls back to current flat tabs. Sidebar DOM stays present but hidden by CSS. Zero-reload rollback via DevTools.
- Full revert: `git revert <phase-2-commits>`.

**Task decomposition:**

- **P2-T1 (2h):** Port `src/icons.jsx` → `js/icons.js`. Write `sidebar.js`: DOM construction from NAV array, active-state toggling, `.count`/`.badge` rendering. Unit-test icon render.
- **P2-T2 (2h):** Write `css/shell.css` (titlebar + sidebar + main-row + side-section + nav-item). Verify in isolation by rendering a static HTML sample.
- **P2-T3 (2h):** Refactor `app.js::setupTabs` → `setupSidebar` + `activateRoute`. Keep legacy `.tab-btn` / `#tabs` as dead code for one release cycle; gate with `editor-v2` body class. Verify every route activates correctly.
- **P2-T4 (1h):** Wire sidebar count refresh into `DirtyTracker` + `FileDiscovery` load/save events. Verify counts update when adding a new prop/biome/recipe.
- **P2-T5 (1h):** Screenshot comparison + manual smoke test (click all 13 routes, confirm editor works identically).

### 3.3 Phase 3 — Master-Detail Layout

**Goal:** Replace the current `.editor-split` / `.editor-list-panel` / `.editor-detail-panel` shell with prototype's 3-column `.master-detail` / `.master` / `.detail` / `.detail-preview`. Form logic inside the detail body is UNCHANGED.

**Files:**

| Action | Path | Notes |
|---|---|---|
| CREATE | `tools/level-editor/css/master-detail.css` | Port prototype `editor.css:731-942` (master-detail, detail-head, section-title, rtable, tag, color-row, ingr-row) + `row`/`input`/`select`/`num`/`slider-row` form controls (`editor.css:603-674`). All scoped under `.editor-v2`. |
| CREATE | `tools/level-editor/js/master-detail.js` | New helper module exporting `mountMasterDetail(container, config)` where `config = { entities, renderMasterRow, renderDetailHead, renderDetailForm, renderDetailPreview, onSelect, onNew, onSearch }`. Every existing editor (prop/biome/recipe/event/journal/cutscene/settings) refactors to use this scaffolding. |
| EDIT | `tools/level-editor/js/prop-editor.js` | Replace top-level layout builder (~30 lines) with `mountMasterDetail(container, config)`. `config.renderDetailForm(model, detailBodyEl)` calls the existing `buildPropForm()` unchanged. All cap editors, CollisionShape editor, MeshVariant editor stay in their current functions. |
| EDIT | `tools/level-editor/js/biome-editor.js` | Same refactor pattern. `renderDetailPreview` shows the biome swatch + (Phase 4 will populate "Used In"). |
| EDIT | `tools/level-editor/js/recipe-editor.js` | Same refactor. |
| EDIT | `tools/level-editor/js/event-editor.js` | Same refactor. |
| EDIT | `tools/level-editor/js/journal-editor.js` | Same refactor. |
| EDIT | `tools/level-editor/js/cutscene-editor.js` | Same refactor. |
| EDIT | `tools/level-editor/js/settings-editor.js` | Settings has no list — uses only `.detail` + `.detail-head` + `.detail-form`. Adapts `mountMasterDetail` with `entities: null`. |
| EDIT | `tools/level-editor/index.html` | Delete legacy `.editor-split`, `.editor-list-panel`, `.editor-detail-panel` CSS (L368–516 + L656–772). Keep `.prop-input`, `.prop-btn*`, `.prop-card`, `.prop-hint`, `.prop-grid` — gear-form-specific, not covered by prototype. |

**Critical invariant:** every form-building function (`buildCapabilityEditor`, `buildCollisionShapeEditor`, `buildMeshVariantEditor`, `renderGearHeader`, `buildResourceTableRow`, etc.) continues to return the same DOM structure. The wrapping `.master-detail` / `.detail-form` containers are new, but what sits inside them is byte-for-byte the same.

**Deliverable:**
- Open Biomes route. Left column (280px) shows biome list with search + "+" button + swatches. Middle shows the selected biome's form (same inputs as today — color, resource table, texture picker, etc.). Right column (280px) shows "USED IN" + "COLORS" + preview hex cluster (Phase 4 populates live data; Phase 3 shows placeholder empty states).
- Open Minerals route. Prop list on left (filtered by category), form in middle (caps, CollisionShapes, MeshVariants — all current logic intact), preview on right.
- Every form field that worked before still works. Save/load still functions.
- Test expectation: 1168/1168 unit + 17/17 roundtrip pass, zero changes to test files.

**Risk items + mitigation:**

| Risk | Mitigation |
|---|---|
| Form container elements hard-coded with old class names (e.g. `.editor-detail-body`) | Audit every `querySelector('.editor-detail-*')` in JS — there should be none if DOM is built incrementally. Master-detail factory passes the new `.detail-form` node into the builder as `container` argument. |
| CSS specificity regressions (legacy `.prop-grid { grid-template-columns: auto 1fr }` vs prototype's `.prop-grid` at 4-col) | Rename prototype's `.prop-grid` → `.prop-palette-grid` in port (see §2.4 collision). |
| Scroll-state loss when switching detail items | Preserve `master-list.scrollTop` + `detail-body.scrollTop` in master-detail factory state. |
| Performance regression from extra wrapping DOM nodes | Negligible — one extra `<div>` per entity, <100 entities total. |
| Forms inside detail-body don't re-layout on column-width changes | Existing forms use `grid-template-columns: auto 1fr` which is responsive. Verify by manual resize. |

**Rollback:**
- Revert Phase 3 commits. All existing form-builder functions are untouched, so a revert restores the old master-detail shell with identical form behavior.
- Mid-migration fallback: ship the refactor one editor at a time (prop → biome → recipe → journal → cutscene → event → settings). Each editor switch is isolated.

**Task decomposition:**

- **P3-T1 (2h):** Write `css/master-detail.css` + `js/master-detail.js` factory. Mount against a fake entity list to verify visual.
- **P3-T2 (2h):** Migrate `biome-editor.js` first — smallest editor by form complexity with a live swatch, good visual win.
- **P3-T3 (3h):** Migrate `prop-editor.js` — largest editor by form complexity. Pay attention to cap editors, MeshVariants, CollisionShapes staying intact.
- **P3-T4 (2h):** Migrate `recipe-editor.js` + `event-editor.js`.
- **P3-T5 (2h):** Migrate `journal-editor.js` + `cutscene-editor.js` + `settings-editor.js`.
- **P3-T6 (1h):** Delete legacy `.editor-split` / `.editor-list-*` / `.editor-detail-*` CSS from `index.html`. Screenshot comparison across all 13 routes.

### 3.4 Phase 4 — Cross-Reference Panels

**Goal:** Populate the right `.detail-preview` column with computed relationships.

**Files:**

| Action | Path | Notes |
|---|---|---|
| CREATE | `tools/level-editor/js/cross-refs.js` | Pure functions: `computeBiomeUsedIn(biomeId, mapsIndex)`, `computePropDropSources(propId, biomesIndex)`, `computePropUsedByRecipes(propId, recipesIndex)` (future-ready). Client-side graph scan. Exports `buildReferenceIndex(projectCtx)` that pre-computes indices once on load, returns a lookup API. |
| EDIT | `tools/level-editor/js/app.js` | On ProjectContext load, build reference index; pass to editors. Rebuild on save. |
| EDIT | `tools/level-editor/js/biome-editor.js` | `renderDetailPreview()` renders "USED IN" panel with `{chapter_id, tile_count}[]` rows. Uses cross-refs index. |
| EDIT | `tools/level-editor/js/prop-editor.js` | `renderDetailPreview()` renders "DROP SOURCES" panel with `{biome_id, chance, min, max}[]` rows. |
| CREATE | `tools/level-editor/css/preview.css` | Preview-specific row styles: `.ref-row`, `.ref-row .swatch`, `.ref-row .meta`, `.ref-row .count`. Port from prototype `editor.css:696-729` (`.prop-item`-style rows). |

**Reference computation (from SPEC):**

| Source | Reference | Algorithm |
|---|---|---|
| Biome | Used In: `{chapter_id, tile_count}[]` | Scan `data/maps/*.json` → count tiles with matching `biome` field. O(maps × tiles) = O(3 × ~500) ≈ 1500 ops. Fast. |
| Prop | Drop Sources | Scan `data/biomes/*.tres` → find `resource_table` entries referencing propId. O(biomes × table-rows) ≈ 12 × 20 = 240 ops. |
| Prop | Used By Recipe | (Future — when recipes are authored) |
| Biome | Swatch preview | Render 7-hex cluster SVG using biome color + shade variations. Pure rendering. |

**Deliverable:**
- Biome detail shows "USED IN: ch1 (147 tiles), ch2 (38 tiles), ch3 (0 tiles)".
- Prop detail shows "DROP SOURCES: biome_grass (80%, 1-3), biome_forest (20%, 1-1)".
- Click-through: clicking a row navigates to that entity.
- Manual verification: edit a biome, save, reopen prop that lives in it — "Drop Sources" reflects the change.

**Risk:**

| Risk | Mitigation |
|---|---|
| Graph scan on load slows startup | Current data sizes are <1ms. Profile only if data grows 100×. |
| Malformed .tres causes crash | Wrap scan in try/catch; on failure show "Unable to compute references" inline. |
| Cross-ref index stale after save | Rebuild index on every save event. |

**Rollback:**
- Revert Phase 4 commits. Detail-preview columns show empty state (from Phase 3 scaffolding).

**Task decomposition:**

- **P4-T1 (2h):** Write `cross-refs.js` with `buildReferenceIndex` + lookup functions + unit tests (add to `test-unit.mjs` — this time we DO add tests for new functionality).
- **P4-T2 (2h):** Wire into `biome-editor.js` preview column. Add "USED IN" panel with `.ref-row` rendering.
- **P4-T3 (2h):** Wire into `prop-editor.js` preview column. Add "DROP SOURCES" panel.
- **P4-T4 (1h):** Write `css/preview.css` with `.ref-row` styling. Screenshot comparison. Manual smoke test for cross-ref correctness.

### 3.5 Nice-to-Haves (Delivery-007, post-Phase 4)

Independent tasks, ship à la carte. Each is ~2–4h:

| # | Feature | Files | Notes |
|---|---|---|---|
| NH1 | Command Palette ⌘K | CREATE `js/command-palette.js`, `css/command-palette.css`. Port `src/command-palette.jsx` (169 LoC) in vanilla JS. | Fuzzy search over NAV + static commands (Save, Export, etc.). |
| NH2 | Status Bar | EDIT `index.html` (add `<footer class="statusbar">`), CREATE `js/statusbar.js`. | Route + dirty-dot + git branch (shell out from server.py) + chapter + encoding + accent-density. |
| NH3 | Hex Preview in Biome Detail | EDIT `biome-editor.js::renderDetailPreview`. | 7-hex SVG cluster with biome color + shade variations. Port from prototype `data-editors.jsx:105-109`. |
| NH4 | Playtest Button (real) | EDIT `index.html` (titlebar button), EDIT `server.py` (new `/playtest` endpoint). | POST to server → subprocess `godot --path /home/andre/projects/Farhaven/`. |
| NH5 | Tweaks Panel | CREATE `js/tweaks.js`, `css/tweaks.css`. Port `src/tweaks.jsx` (52 LoC). | Runtime accent swap (amber/blue/green/violet), density toggle (compact/comfortable), via `data-accent` and `data-density` attrs. |

---

## 4. Part C — Phase 1 Pre-Flight

### 4.1 New file: `tools/level-editor/css/tokens.css`

Exact content, ready to paste:

```css
/* ==========================================================================
   Farhaven Editor — Design Tokens (Phase 1)
   Ported from temp/Farhaven Editor/editor.css:5-55
   ========================================================================== */

:root {
  /* Neutral graphite scale */
  --bg-0: #0f1014;        /* darkest — app background */
  --bg-1: #15171d;        /* panel */
  --bg-2: #1c1f27;        /* card / input */
  --bg-3: #262a35;        /* hover */
  --bg-4: #333847;        /* active */

  --line:   #22252e;      /* hairline borders */
  --line-2: #2d313c;      /* stronger borders */

  /* Text scale */
  --text-0: #e8eaf0;      /* primary */
  --text-1: #a5a9b5;      /* secondary */
  --text-2: #6d7280;      /* tertiary / labels */
  --text-3: #4a4e58;      /* disabled */

  /* Accents — warm from Farhaven game palette */
  --amber:     #f4a261;
  --amber-dim: #b97a47;
  --amber-bg:  rgba(244, 162, 97, 0.14);   /* matches runtime (app.jsx:189) */

  --blue:   #5bb5e0;
  --green:  #7ec886;
  --red:    #e07b7b;
  --gold:   #f0d060;
  --violet: #a88bd9;

  --accent:    var(--amber);
  --accent-bg: var(--amber-bg);

  /* State (Phase 1 addition — covers error banners used across editors) */
  --bg-error:   #4a1c1c;
  --line-error: #7a3030;
  --text-error: #ff9999;

  /* Biome colors — lifted from .tres files */
  --biome-crash:  #8b7355;
  --biome-grass:  #66bf4d;
  --biome-forest: #2d8b46;
  --biome-rocky:  #9e8b78;
  --biome-water:  #4a9bd9;
  --biome-desert: #d4b269;
  --biome-ash:    #4b4852;
  --biome-tundra: #c8d2dc;

  /* Metrics */
  --radius:     4px;
  --radius-lg:  6px;
  --h-titlebar: 36px;
  --h-tabs:     34px;
  --h-status:   24px;
  --w-tabrail:  52px;

  /* Typography */
  --font-sans: 'Inter', ui-sans-serif, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  --font-mono: 'IBM Plex Mono', ui-monospace, 'SFMono-Regular', Menlo, monospace;

  /* --------------------------------------------------------------
     LEGACY ALIASES — keep the current editor's CSS working while
     we migrate. Delete once no selector references these names.
     -------------------------------------------------------------- */
  --bg-primary:    var(--bg-0);
  --bg-secondary:  var(--bg-1);
  --bg-tertiary:   var(--bg-2);
  --text-primary:  var(--text-0);
  --text-secondary: var(--text-1);
  --accent-hover:  var(--amber-dim);
  --danger:        var(--red);
  --warning:       var(--gold);
  --success:       var(--green);
  --border:        var(--line-2);
  --tab-active:    var(--bg-3);
  --tab-hover:     var(--bg-2);
}

/* Accent swap via data attr (nice-to-have NH5; harmless if unused) */
[data-accent="blue"]   { --accent: var(--blue);   --accent-bg: rgba( 91,181,224,0.14); }
[data-accent="green"]  { --accent: var(--green);  --accent-bg: rgba(126,200,134,0.14); }
[data-accent="violet"] { --accent: var(--violet); --accent-bg: rgba(168,139,217,0.14); }
```

### 4.2 Edits to `tools/level-editor/index.html` (head + top of style block)

**Add to `<head>` (before the `<style>` tag around line 7):**

```html
  <!-- Google Fonts — Inter + IBM Plex Mono -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500;600&display=swap" rel="stylesheet">

  <!-- Design tokens (Phase 1) -->
  <link rel="stylesheet" href="css/tokens.css">
```

**Inside `<style>` block — token var replacements (diff-style):**

```
--- tools/level-editor/index.html (existing inline CSS)
+++ tools/level-editor/index.html (after Phase 1)
@@ lines 17-31 (`:root` block)
-:root {
-  --bg-primary: #1e1e2e;
-  --bg-secondary: #2a2a3c;
-  --bg-tertiary: #333348;
-  --text-primary: #e0e0e8;
-  --text-secondary: #a0a0b0;
-  --accent: #6ea8fe;
-  --accent-hover: #8dbcff;
-  --danger: #f06060;
-  --warning: #e8a020;
-  --success: #60c060;
-  --border: #444460;
-  --tab-active: #3a3a50;
-  --tab-hover: #2f2f45;
-}
# REMOVE this entire `:root` block. tokens.css provides all vars
# plus legacy aliases (see §4.1). Leaving it would shadow our
# new values because inline styles load after the external link.

@@ lines 33-40 (`html, body`)
-html, body {
-  height: 100%;
-  overflow: hidden;
-  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
-  font-size: 14px;
-  color: var(--text-primary);
-  background: var(--bg-primary);
-}
+html, body {
+  height: 100%;
+  overflow: hidden;
+  font-family: var(--font-sans);
+  font-size: 12.5px;
+  line-height: 1.4;
+  -webkit-font-smoothing: antialiased;
+  color: var(--text-0);
+  background: var(--bg-0);
+}
```

Remaining substitutions (grep-and-replace across `<style>`, keeping semantics):

```
var(--bg-primary)     → var(--bg-0)      (app background)
var(--bg-secondary)   → var(--bg-1)      (panels, toolbar)
var(--bg-tertiary)    → var(--bg-2)      (cards, inputs)
var(--text-primary)   → var(--text-0)
var(--text-secondary) → var(--text-1)    — or --text-2 for form labels
var(--border)         → var(--line-2)    — or --line for hairlines
var(--tab-active)     → var(--bg-3)
var(--tab-hover)      → var(--bg-2)
var(--accent-hover)   → var(--amber-dim)
var(--danger)         → var(--red)
var(--warning)        → var(--gold)
var(--success)        → var(--green)
```

**Count of literal-hex occurrences to keep an eye on** (for thoroughness):
- `<style>` block (lines 7–995): should drop to zero after replacements except possibly `#ff9999` (error text), `#7a3030` (error border), `#4a1c1c` (error bg), `#7a3030`, `#ff9999` scattered inline color overrides — these become `var(--text-error)` / `var(--line-error)` / `var(--bg-error)`.

### 4.3 Edits to JS inline-style literals

**Error-banner pattern** (same 5-property block used in 7 files):

```
Before:
  errorArea.style.cssText = 'display:none;padding:6px 10px;margin:4px 12px 0;background:#4a1c1c;border:1px solid #7a3030;border-radius:4px;color:#ff9999;font-size:12px;';

After:
  errorArea.style.cssText = 'display:none;padding:6px 10px;margin:4px 12px 0;background:var(--bg-error);border:1px solid var(--line-error);border-radius:4px;color:var(--text-error);font-size:12px;';
```

Files with this pattern:
- `tools/level-editor/js/event-editor.js:846`
- `tools/level-editor/js/biome-editor.js:580`
- `tools/level-editor/js/prop-editor.js:1894`
- `tools/level-editor/js/recipe-editor.js:996`
- `tools/level-editor/js/journal-editor.js:615`
- `tools/level-editor/js/cutscene-editor.js:572`
- `tools/level-editor/js/panels.js:169, 193` (similar patterns)

**Other**:
- `js/app.js:793`: `btnApply.style.background = 'var(--danger, #7a3030)';` → `var(--red, #7a3030)` (keep fallback for defense).
- `js/prop-editor.js:1004, 1009`: `'var(--accent, #4a9eff)'` fallback — change to `'var(--accent, #f4a261)'` so the fallback matches the new default. Minor defense-in-depth.

**Leave untouched (Phase 3 or later):**
- `js/hex-grid.js:79-88` `CATEGORY_COLORS` — Canvas2D rendering, CSS vars don't help.
- `js/canvas.js:11,17-20` — Canvas2D rendering.

### 4.4 Verification Plan

1. **Boot**: `cd tools/level-editor && python3 server.py`, open browser.
2. **Font check**: `document.body.style.fontFamily` in DevTools → includes `'Inter'`.
3. **Token check**: `getComputedStyle(document.documentElement).getPropertyValue('--bg-0').trim()` → `#0f1014`.
4. **Screenshot comparison points** (save under `docs/screenshots/phase1/`):
   - `before-sidebar.png` vs `after-sidebar.png` (map-tab left rail)
   - `before-prop-form.png` vs `after-prop-form.png` (minerals tab, pick any prop)
   - `before-biome-form.png` vs `after-biome-form.png` (biomes tab, pick any biome)
   - `before-map.png` vs `after-map.png` (map tab, default view)
5. **Unit tests**: `node tools/level-editor/test-unit.mjs` → `1168 passed, 0 failed`.
6. **Roundtrip**: `node tools/level-editor/test-roundtrip.mjs` → `17/17 passed`.
7. **Hover/focus states**: interact with input — border turns amber on focus.
8. **Error banner**: intentionally trigger validation error (save prop with empty ID) → banner shows correct amber-on-dark error styling.

---

## 5. Part D — Branching + Merge Strategy

**Recommendation: one feature branch, per-phase sub-branches merged into it, single squash to `main` per delivery.**

### Branch layout

```
main
  └── feature/editor-redesign               (long-lived feature branch)
        ├── feature/editor-redesign-p1      (merges into feature/editor-redesign)
        ├── feature/editor-redesign-p2      (merges into feature/editor-redesign)
        ├── feature/editor-redesign-p3      (merges into feature/editor-redesign)
        └── feature/editor-redesign-p4      (merges into feature/editor-redesign)
```

- Each phase branch is a PR into `feature/editor-redesign`.
- Each PR is squash-merged (clean commit history per phase).
- When Phases 1–3 are merged + verified on `feature/editor-redesign`, open a single PR `feature/editor-redesign` → `main` for **delivery-005**. Squash-merge with comprehensive commit message listing all 3 phases.
- Then cut `feature/editor-redesign-p4` off `main` (fresh base) for delivery-006.

**Why not one-branch-per-delivery?** Phase 2 depends on Phase 1's tokens. Phase 3 depends on Phase 2's `.editor-v2` wrapper. Rebasing those dependencies through three separate branches is painful. A long-lived feature branch lets each phase build on the previous without rebase dance.

**Why not one-PR-per-phase straight to main?** Because Phase 1 alone ships fine (nice color refresh); Phase 2 alone also ships (sidebar works even without master-detail refactor); Phase 3 alone depends on Phases 1+2 being merged first. If we want the "incremental delivery" property (Andre's constraint #4), each phase PR must be independently shippable **from main** — which means Phase 1 must go to main before Phase 2 starts. That's option B below.

**Two equally valid strategies** — pick one:

| Strategy | Pros | Cons |
|---|---|---|
| **A. Long-lived `feature/editor-redesign` + per-phase sub-branches, ship via single delivery-005 PR to main** | Clean main history (1 commit per delivery). Safe: main never sees half-migrated state. | Users on main don't benefit until all 3 phases merge. Rollback granularity = whole delivery. |
| **B. Per-phase PR directly to main** (`feature/editor-redesign-p1` → main, then p2, then p3) | Users get Phase 1 visual win immediately. Rollback granularity = single phase. Matches SPEC's "phases can ship independently" language. | More main-history noise (3 commits for delivery-005). Requires Phase 1 be 100% safe against regression (it is — tokens only). |

**Recommendation: Strategy B** (per-phase to main). Matches Andre's constraint #4 ("Incremental delivery — phases can ship independently. Each must be runnable on its own and rollback-able"). Phase 1 is the visual quick-win Andre asked for; shipping it alone is the entire point. Subsequent phases build off the new `main` without rebase churn.

### Keeping `main` shippable between phases

- Phase 1 ships tokens-only; no structural markup changes → main stays shippable.
- Phase 2 introduces `.editor-v2` body class; legacy nav/tabs stay as fallback gated by `document.body.classList.contains('editor-v2')`. If Phase 2 ships broken, hotfix is `body.classList.remove('editor-v2')` in a single JS line — main is shippable.
- Phase 3 migrates one editor at a time (6 editors in sub-commits); each migration PR is a checkpoint. Main is shippable after every migration.
- Phase 4 is purely additive (preview columns populated) — main stays shippable.

### Merge strategy per phase

- **Squash** all phase PRs (clean history, single revertable commit per phase).
- Commit message template:
  ```
  feat(editor): Phase N — <short name>

  Ports <prototype files> to vanilla JS:
  - <file 1>
  - <file 2>

  Verified:
  - 1168 unit asserts pass
  - 17 roundtrip tests pass
  - Screenshots at docs/screenshots/phaseN/

  Rollback: revert this commit.

  Refs: feature-010, delivery-005
  ```

### Pre-flight per phase (before merge to main)

- `node tools/level-editor/test-unit.mjs` green.
- `node tools/level-editor/test-roundtrip.mjs` green.
- `node tools/level-editor/verify-walls.mjs` green.
- Manual smoke test checklist (per phase — see §3 "Deliverable" sections).
- Screenshots archived under `docs/screenshots/phaseN/`.

---

## 6. Part E — Open Questions for Andre

Before I hand this plan to a developer agent, I need concrete answers to these 5 decisions:

**Q1 (Fonts — BLOCKING Phase 1):** SPEC §Phase 1 line 84 says `--font-sans` is "IBM Plex Sans", but the prototype loads `Inter` from Google Fonts and your preamble says "Inter, IBM Plex Mono". Confirm: `--font-sans` uses **Inter** first (my assumption in §4.1). Y/N?

**Q2 (Accent opacity — BLOCKING Phase 1):** Prototype `:root` declares `--amber-bg: rgba(244, 162, 97, 0.12)`, runtime code in `app.jsx:189` overrides with 0.14. Confirm: ship **0.14** (the value the designer actually ships at runtime). Y/N? If you want 0.12 we use that.

**Q3 (Orphan prop categories — BLOCKING Phase 2):** Current editor has 11 prop categories (mineral, plant, animal, fungi, ooze, liquid, stuff, structure, equipment, vehicle, storage). Prototype NAV has 6 (plant, animal, mineral, structure, equipment, storage). What do we do with **fungi, ooze, liquid, stuff, vehicle**?
- (a) Add 5 more NAV items under PROPS section with custom icons (e.g., fungi → mushroom icon).
- (b) Fold fungi+ooze into "Flora", liquid+stuff into "Minerals", vehicle into "Equipment".
- (c) Keep a "MORE" subsection under PROPS collapsible by default.

**Q4 (Namespace — BLOCKING Phase 2):** I recommend `.editor-v2` body wrapper over `fh-` prefix (see §2.5 justification). Confirm, or override with `fh-`?

**Q5 (Delivery boundary — affects scheduling):** SPEC maps delivery-005 to Phases 1–3. But you said phases should ship independently. Options:
- (a) Ship **Phase 1 alone** as delivery-005a, Phases 2–3 as delivery-005b (fastest visual win to users, 2 deliveries).
- (b) Keep SPEC mapping: Phases 1–3 bundled as delivery-005 (one delivery, bigger blast).
- (c) Three separate deliveries: 005a = P1, 005b = P2, 005c = P3.

My recommendation: **(a)** — Phase 1 is the 2-hour "quick visual win" you described; sitting on it waiting for P2+P3 defeats the purpose.

---

### Critical Files for Implementation

- `/home/andre/projects/Farhaven/tools/level-editor/index.html` (1211 LoC — shell markup + legacy inline CSS; touched in every phase)
- `/home/andre/projects/Farhaven/tools/level-editor/js/app.js` (1753 LoC — tab routing → sidebar routing in Phase 2; reference-index wiring in Phase 4)
- `/home/andre/projects/Farhaven/tools/level-editor/js/prop-editor.js` (3845 LoC — largest editor; Phase 3 master-detail migration + Phase 4 drop-sources preview)
- `/home/andre/projects/Farhaven/tools/level-editor/js/biome-editor.js` (1656 LoC — Phase 3 master-detail migration + Phase 4 used-in preview)
- `/home/andre/projects/Farhaven/temp/Farhaven Editor/editor.css` (1392 LoC — the entire design-system source; ported to `css/tokens.css` + `css/shell.css` + `css/master-detail.css` across phases)
