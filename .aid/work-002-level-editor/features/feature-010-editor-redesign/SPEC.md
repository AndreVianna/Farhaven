# Editor Redesign — Port Claude Design System & IA

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-17 | Initial spec drafted from external Claude Design prototype | Lola |

## Source

- External design spec: `temp/Farhaven Editor/` (React prototype, 28 LoC HTML + 1392 LoC CSS + ~2100 LoC JSX)
- Proposed REQUIREMENTS.md addition: **F16 Editor Design System & Master-Detail IA** (pending approval)
- Origin: Andre used Anthropic's Claude Design tool on 2026-04-17 to generate a full editor redesign proposal

## Description

The current editor (`tools/level-editor/`) is functionally complete but visually rough. It uses a flat category list, a single-column scrollable form, and inconsistent spacing/colors. The Claude Design prototype proposes a cohesive design system (tokens, typography, spacing), a hierarchical sidebar organized by domain (WORLD / PROPS / SYSTEMS / NARRATIVE / PROJECT), and a master-detail layout with contextual preview panels and cross-references.

This feature ports that design language and information architecture into the existing vanilla JS editor. The existing form logic (typed capabilities, `CollisionShape` composition, `MeshVariant` with scale/rotation, `TresParser` round-trip) is preserved intact — only the surrounding shell and styling change. The redesign is delivered in 4 incremental phases plus post-phase nice-to-haves.

**What is NOT in scope:**
- Not a React migration. The prototype is React/UMD; we reimplement in vanilla JS.
- Not a data-layer rewrite. `PropDefModel`, `CapabilityEditor`, `TresParser` stay.
- Not a feature-parity replay of the prototype (some prototype widgets are mock — e.g. Playtest button, hardcoded "USED IN" counts).

## User Stories

- As Andre, I want the editor sidebar organized by domain (WORLD / PROPS / SYSTEMS / NARRATIVE) so that I can find the right screen without scanning a flat list
- As Andre, I want a master-detail layout (list column + detail column + preview column) so that I can navigate entries without losing context of the current selection
- As Andre, I want to see cross-references (which chapters use this biome, which biomes drop this prop) so that I understand data dependencies before editing
- As Andre, I want consistent visual design (tokens, amber accent, monospace IDs) so that the editor feels like a finished tool instead of a prototype
- As Lola, I want the visual upgrade without losing the form logic (caps, CollisionShapes, MeshVariants) so that today's work on data authoring is preserved

## Priority

Should (not blocking game work, but high leverage — improves every future authoring session)

## Acceptance Criteria

- [ ] Given the editor loads, when the sidebar is rendered, then entries are grouped under WORLD / PROPS / SYSTEMS / NARRATIVE / PROJECT section headers with per-item counts
- [ ] Given the user opens any data editor (props, biomes, recipes, etc.), when the layout is rendered, then a 3-column master-detail structure is visible (list column with search + detail column with form + preview column with metadata)
- [ ] Given the user selects a biome, when the detail preview is rendered, then a "Used In" panel lists all chapters referencing this biome with tile counts
- [ ] Given the user selects a prop, when the detail preview is rendered, then a "Drop Sources" panel lists all biomes that include this prop in their resource table
- [ ] Given the design system is applied, when any control is rendered, then colors, typography, and spacing match the token scale defined in `editor.css` (not arbitrary values)
- [ ] Given the redesign is deployed, when existing forms are rendered (Prop editor with caps, Biome editor with resource table), then all form logic from feature-005 (Resource Editor) and feature-006 (Biome Editor) functions identically to pre-redesign behavior
- [ ] Given existing tests (1108 unit + 17 roundtrip) are run, when the redesigned editor is loaded, then all tests pass without modification

---

## Technical Specification

### Design Source

The reference implementation lives at `temp/Farhaven Editor/` on branch `feature/props-grassland` (commit `fc1d36f Design proposal`). It is a standalone React prototype meant to serve as a visual spec, not as a drop-in replacement.

Key files:

| Prototype file | Purpose |
|---|---|
| `Editor.html` | Shell with React UMD + Babel standalone bootstrap |
| `editor.css` | **1392 LoC design system** — tokens, layouts, component styles |
| `src/app.jsx` | TitleBar, Sidebar, StatusBar, NAV definition, tweaks/accent/density |
| `src/data-editors.jsx` | Master-detail pattern for Biome, Prop, Recipe, Journal, Cutscene, Settings |
| `src/hex-canvas.jsx` | SVG hex renderer (reference for visual polish of existing map view) |
| `src/command-palette.jsx` | ⌘K palette (Phase 5 nice-to-have) |
| `src/icons.jsx` | 59 LoC of inline SVG icons |

### Phase 1: Design Tokens & Typography

**Goal:** Apply the prototype's visual language to the existing editor with zero structural changes. Instant 70%-of-the-way-there visual upgrade.

**Files touched:**
- `tools/level-editor/css/tokens.css` (new) — port `:root` vars from `editor.css` lines 5–55
- `tools/level-editor/css/editor.css` (existing) — replace ad-hoc colors/fonts with `var(--bg-1)`, `var(--text-0)`, `var(--accent)`, etc.
- `tools/level-editor/index.html` — add Google Fonts preconnect + Inter + IBM Plex Mono link tags

**Token categories to port:**

1. **Neutral graphite scale** — `--bg-0` through `--bg-4`, `--line`, `--line-2`
2. **Text scale** — `--text-0` through `--text-3`
3. **Accents** — `--amber`, `--amber-dim`, `--amber-bg`, plus `--blue`, `--green`, `--red`, `--gold`, `--violet`
4. **Biome colors** — `--biome-crash`, `--biome-grass`, etc. (centralizes magic hex values currently scattered in JS)
5. **Metrics** — `--radius`, `--radius-lg`, `--h-titlebar`, `--h-tabs`, `--h-status`, `--w-tabrail`
6. **Fonts** — `--font-sans` (IBM Plex Sans), `--font-mono` (IBM Plex Mono)

**Deliverable:** editor looks like the prototype for fonts, colors, borders, spacing — but keeps current layout structure.

### Phase 2: Sidebar Reorg by Domain

**Goal:** Replace the current flat category dropdown with a hierarchical sidebar matching the prototype's IA.

**Files touched:**
- `tools/level-editor/js/app.js` — extract a `Sidebar` module; define `NAV` array matching `app.jsx` lines 5–19
- `tools/level-editor/index.html` — swap the current sidebar markup for the `<aside class="sidebar">` structure
- `tools/level-editor/css/editor.css` — port `.side-section`, `.side-header`, `.nav-item`, `.count`, `.badge` styles

**NAV structure:**

```js
const NAV = [
  { id: 'maps',      section: 'WORLD',     label: 'Maps',      icon: 'map',    badge: '<dirty_count>' },
  { id: 'biomes',    section: 'WORLD',     label: 'Biomes',    icon: 'brush',  count: BIOMES.length },
  { id: 'events',    section: 'WORLD',     label: 'Events',    icon: 'bolt',   count: EVENTS.length },
  { id: 'plant',     section: 'PROPS',     label: 'Flora',     icon: 'leaf',   count: PROPS.filter(p => p.category === 'plant').length },
  { id: 'animal',    section: 'PROPS',     label: 'Fauna',     icon: 'paw',    count: PROPS.filter(p => p.category === 'animal').length },
  { id: 'mineral',   section: 'PROPS',     label: 'Minerals',  icon: 'rocks',  count: ... },
  { id: 'structure', section: 'PROPS',     label: 'Structures',icon: 'house',  count: ... },
  { id: 'equipment', section: 'PROPS',     label: 'Equipment', icon: 'tool',   count: ... },
  { id: 'storage',   section: 'PROPS',     label: 'Storage',   icon: 'box',    count: ... },
  { id: 'recipes',   section: 'SYSTEMS',   label: 'Recipes',   icon: 'flask',  count: RECIPES.length },
  { id: 'journal',   section: 'NARRATIVE', label: 'Journal',   icon: 'book',   count: JOURNAL.length },
  { id: 'cutscenes', section: 'NARRATIVE', label: 'Cutscenes', icon: 'film',   count: CUTSCENES.length },
  { id: 'settings',  section: 'PROJECT',   label: 'Settings',  icon: 'gear' },
];
```

**Routing:** Current editor has 3 tabs (map, resources, biomes). The new sidebar has 13 routes. Initial port:
- Keep existing tab behavior for map/resources/biomes (routes: `maps`, `mineral`/`plant`/etc. all point to the Resource editor filtered by category, `biomes` points to Biome editor)
- Show placeholder "not yet implemented" screens for new routes (events, recipes, journal, cutscenes, settings) — those become future features

**Icons:** Port `src/icons.jsx` verbatim (it's pure SVG strings, no React dependency).

### Phase 3: Master-Detail Layout

**Goal:** Replace the current single-column form layout with the prototype's 3-column master-detail pattern.

**Files touched:**
- `tools/level-editor/js/prop-editor.js` — wrap existing form logic in new shell structure
- `tools/level-editor/js/biome-editor.js` — same
- `tools/level-editor/css/editor.css` — port `.master-detail`, `.master`, `.master-head`, `.master-list`, `.master-row`, `.detail`, `.detail-head`, `.detail-body`, `.detail-form`, `.detail-preview`, `.section-title`, `.row`, `.ctrl`, `.input` from `editor.css` lines covering master-detail (~300 LoC block)

**Layout structure:**

```
┌─────────────┬──────────────┬────────────────────────┬──────────────┐
│             │              │                        │              │
│  SIDEBAR    │  MASTER      │  DETAIL                │  PREVIEW     │
│  (Phase 2)  │  (list)      │  (form — existing      │  (metadata,  │
│             │              │   logic preserved)     │   cross-refs)│
│             │  [search]    │                        │              │
│             │  [+ new]     │  [head: title/actions] │              │
│             │              │  [form sections]       │              │
│             │  ┌────────┐  │                        │              │
│             │  │ entry  │  │                        │              │
│             │  │ entry  │  │                        │              │
│             │  │ entry* │  │                        │              │
│             │  └────────┘  │                        │              │
└─────────────┴──────────────┴────────────────────────┴──────────────┘
```

**Critical constraint:** the Detail Form section reuses existing form-building code from feature-005 (prop editor) and feature-006 (biome editor) unchanged. Only the wrapping HTML structure and CSS classes change. All `PropDefModel`, `CapabilityEditor`, `CollisionShape` editor, `MeshVariant` editor logic stays intact.

### Phase 4: Cross-Reference Panels

**Goal:** Populate the Detail Preview column with computed relationships between entities.

**Files touched:**
- `tools/level-editor/js/cross-refs.js` (new) — graph analyzer
- `tools/level-editor/server.py` — optional endpoint for pre-computing refs (or do client-side if acceptable)
- `tools/level-editor/js/biome-editor.js`, `js/prop-editor.js` — render preview column

**Reference types to compute:**

| Source entity | Reference | How |
|---|---|---|
| Biome | Used In: `{chapter_id, tile_count}[]` | Scan all `data/maps/*.json`, count tiles with matching `biome` field |
| Biome | Resource Table shown | Already stored in `BiomeData.resource_table` |
| Prop | Drop Sources: `{biome_id, chance, min, max}[]` | Scan all `data/biomes/*.tres`, find entries in `resource_table` referencing this prop |
| Prop | Used By Recipe: `{recipe_id}[]` | (Future — when recipes are authored) |
| Biome color swatch | Live preview | Render 7-hex cluster SVG using the biome's color + shade variations |

**Performance:** Computation is O(maps × tiles) + O(biomes × resources). For current data (3 maps, 12 biomes, 12 props), sub-millisecond — can run client-side on load.

### Nice-to-Haves (Post Phase 4)

Deferred to future tasks, spec here for tracking:

1. **Command Palette ⌘K** — Port `src/command-palette.jsx` (169 LoC). Fuzzy-search navigation + common commands (Save, Export .tres, Playtest, New Prop, etc.).
2. **Status Bar** — Port the bottom status bar from `app.jsx`: `unsaved · main 2 ahead · route · hex coords · tool · tile count · encoding · accent+density`
3. **Hex Preview in Biome Detail** — Port the SVG cluster render from `data-editors.jsx` lines 105–109
4. **Playtest Button (real)** — POST to server.py endpoint that launches `godot --path /home/andre/projects/Farhaven/` in a subprocess
5. **Tweaks Panel** — Port `src/tweaks.jsx` (52 LoC). Runtime accent/density/layout toggles via data attributes

### Edge Cases

| Scenario | Behavior |
|---|---|
| Existing CSS class conflicts (e.g. `.input`, `.btn`) | Namespace new classes with `fh-` prefix or isolate via a `.editor-v2` wrapper class on `<body>` during migration |
| User has an older browser without CSS custom property support | Out of scope — editor has always required modern browsers (File System Access API is more restrictive than CSS custom props) |
| Phase 1 shipped alone, user expects full redesign | Communicate in commit message + release note that phases ship incrementally |
| New NAV routes without backing data (e.g. "Events" when no events exist) | Show empty state: "No events defined yet" with a primary "+ New Event" button |
| Cross-ref computation fails (e.g. malformed biome .tres) | Show reference panel with a gray "Unable to compute references" note; do not block the main editor |
| Font loading fails (Google Fonts blocked) | CSS `--font-sans` fallback chain includes `ui-sans-serif, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`; acceptable degradation |

### Implementation Phasing Summary

| Phase | Scope | Risk | Estimated Tasks |
|---|---|---|---|
| 1 | Tokens + fonts | Low — CSS-only, reversible by deleting tokens.css | 1 task |
| 2 | Sidebar reorg | Low — additive, existing flat nav stays working until cutover | 1–2 tasks |
| 3 | Master-detail | Medium — restructures form wrappers; tests must all still pass | 2–3 tasks |
| 4 | Cross-refs | Medium — new feature, requires graph scan over .tres files | 1–2 tasks |
| Nice-to-haves | ⌘K, status bar, hex preview, Playtest, tweaks | Low (individual), ship à la carte | 4–5 tasks |

**Delivery mapping (proposed addition to PLAN.md):**

### delivery-005: Editor Redesign — Foundation

**Features:** 010 (Editor Redesign), Phase 1–3 only
**Depends on:** 001, 003, 005, 006 (existing map/sidebar/resource/biome editors must be complete and tested)
**Cumulative state:** Editor with design system, domain-organized sidebar, master-detail layout. Forms functionally identical.

### delivery-006: Editor Cross-References

**Features:** 010 (Editor Redesign), Phase 4
**Depends on:** delivery-005
**Cumulative state:** "Used In" and "Drop Sources" panels live; editors show data dependencies.

### delivery-007: Editor Quality-of-Life (optional)

**Features:** 010 (Editor Redesign), nice-to-haves
**Depends on:** delivery-006
**Cumulative state:** Command palette, status bar, hex preview, live Playtest, runtime tweaks.
