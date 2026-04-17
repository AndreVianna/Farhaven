# Delivery Plan — work-002-level-editor

**Status:** Approved
**Created:** 2026-04-03
**Features:** 10 (001–009 Ready + 010 Ready pending tasks)
**Minimum grade:** A

## Dependency Map

| Feature | Depends On | Enables |
|---------|-----------|---------|
| 007 File Discovery | -- (foundation) | 001, 003, 004, 005, 006 |
| 008 Command Infrastructure | -- (foundation) | 001, 002, 003, 005, 006, 009 |
| 009 Unsaved Changes | 008 (CommandHistory.onChange) | 003 (dirty indicators) |
| 001 Hex Canvas | 007 (biome colors), 008 (command forwarding) | 002, 003, 004 |
| 002 Painting Tools | 001 (canvas events), 008 (commands) | 003 (tool indicator) |
| 003 Palette & Sidebar | 001, 002, 005, 006, 007, 009 | -- (integration glue) |
| 004 Import/Export | 001 (HexGrid model), 007 (file handles), 008 (Ctrl+S) | -- |
| 005 Resource Editor | 007 (TresParser, handles), 008 (commands) | 003 (resource palette), 006 (resource dropdown) |
| 006 Biome Editor | 007 (TresParser, handles), 008 (commands), 005 (resource dropdown) | 001 (live color preview), 003 (biome palette) |
| 010 Editor Redesign | 001, 003, 005, 006 (existing UI must be tested before restyling) | -- (visual polish layer) |

**Key dependency notes:**
- F-007 (File Discovery) and F-008 (Command Infrastructure) are the two zero-dependency foundations
- F-003 (Palette & Sidebar) has the highest fan-in — it is the integration glue connecting nearly everything
- F-005 (Resource Editor) must precede F-006 (Biome Editor) because biome resource_table dropdown needs resource IDs
- F-004 (Import/Export) is independent of the .tres editors — only needs the HexGrid model + file handles
- F-010 (Editor Redesign) runs on top of a complete editor — restyles existing components without changing form logic

## Deliveries

### delivery-001: Editor Foundation

**Features:** 007 (File Discovery) + 008 (Command Infrastructure) + 009 (Unsaved Changes)
**Depends on:** --
**Cumulative state:** App shell with tabs, project folder selection, file discovery, .tres parsing, command history, keyboard shortcuts, dirty tracking + beforeunload protection

Build order:
1. feature-007 (File Discovery) — app shell HTML skeleton, tab switching, folder picker, TresParser, ProjectContext. **Note:** This is the heaviest feature — TresParser alone handles typed arrays, PackedStringArray, dict key styles, round-trip validation. Expect 5-6 tasks.
2. feature-008 (Command Infrastructure) — CommandHistory, KeyboardManager, per-tab shortcut scoping
3. feature-009 (Unsaved Changes) — DirtyTracker wired to CommandHistory.onChange, beforeunload, tab indicators

**AC coverage:** Partial AC2 (.tres round-trip parsing), AC8 (unsaved changes protection)

#### Execution Graph

| Task | Depends On |
|------|-----------|
| task-001 | -- |
| task-002 | task-001 |
| task-003 | task-002 |
| task-004 | task-001 |
| task-005 | task-004 |
| task-006 | task-002, task-003, task-004, task-005 |

| Can Be Done In Parallel |
|------------------------|
| task-002, task-004 |
| task-003, task-005 |

### delivery-002: See the Map — Hex Canvas + Painting

**Features:** 001 (Hex Canvas) + 002 (Painting Tools)
**Depends on:** delivery-001
**Cumulative state:** Visual hex grid rendered from loaded data, all painting tools functional, biome/elevation/resource/structure/anomaly/spawn editing, flood fill, undo/redo on all operations

Build order:
1. feature-001 (Hex Canvas) — HexMath, HexGrid model, Canvas2D rendering, zoom/pan/hover/tooltips
2. feature-002 (Painting Tools) — ToolManager, 9 tool classes, ResourceDetailPanel, all Command classes

**2026-04-04 retrofit:** Sub-hex grid system added. Resources use discrete (sq, sr) positions instead of continuous (x, y). Structures use footprint (list of sub-hexes). Canvas shows sub-hex overlay for placement tools.

**2026-04-04 retrofit:** Unified props model -- resources/structures/anomalies collapsed into single props[] array per tile. Each prop: {type, sq, sr, category, rotation?, footprint?}. Commands unified: AddProp/EditProp/DeleteProp replace per-category commands. Spawn stays in grid.meta (not a prop). EraseContentCommand clears all props. ResourceDetailPanel renamed PropDetailPanel. Legacy import converts old format to props[].

This is the visual payoff. After this delivery, the user can see a hex map rendered with correct biome colors, elevation overlays, cliff indicators, and can paint/edit it with all tools.

**AC coverage:** AC7 (undo/redo), partial AC3 (authoring), AC10 (map expansion via ghost grid)

#### Execution Graph

| Task | Depends On |
|------|-----------|
| task-007 | task-001 |
| task-008 | task-007, task-002 |
| task-009 | task-008, task-004 |
| task-010 | task-009 |
| task-011 | task-008, task-009, task-010 |
| task-011b | task-008, task-009 |

task-011b (Ghost Grid & Empty-Cell Interaction) can run in parallel with task-011 since both depend on task-008/009/010 being complete.

| Can Be Done In Parallel |
|------------------------|
| task-011, task-011b |

### delivery-003: Tool Selector, Map List, Data Editors

**Features:** 003-partial (Tool Selector + Map List) + 005 (Resource Editor) + 006 (Biome Editor)
**Depends on:** delivery-001, delivery-002
**Cumulative state:** Painting tools fully usable via sidebar palette (biome/resource/structure/anomaly selectors), map list with switching, full CRUD for PropDef and BiomeData .tres files, live biome color preview on map canvas

**2026-04-04:** Moved tool selector and map list from delivery-004 to delivery-003. Without these, delivery-002's painting tools are barely testable — tools activate via keyboard but have no way to select which type to paint with.

Build order:
1. feature-003-partial (Tool Selector + Map List) — toolbar with tool buttons + type dropdowns populated from loaded data, map list dropdown for switching active map
2. feature-005 (Resource Editor) — list/edit/create/delete PropDef, .tres serialization
3. feature-006 (Biome Editor) — list/edit/create/delete BiomeData, resource table editor, live color preview

F-003-partial depends on delivery-002 (needs canvas + tools). F-005 and F-006 depend only on delivery-001 (TresParser). F-005 must precede F-006 (biome resource_table dropdown needs resource IDs).

**AC coverage:** AC2 (.tres round-trip save), AC4 (resource CRUD), AC5 (biome CRUD), partial AC3 (tool selector enables full painting workflow)

#### Execution Graph

| Task | Depends On |
|------|-----------|
| task-012 | task-003, task-004 |
| task-012b | task-008, task-009, task-010 |
| task-013 | task-012 |
| task-014 | task-003, task-004, task-012 |
| task-015 | task-014 |
| task-016 | task-012b, task-013, task-015 |

task-012b = Tool Selector + Map List (new task, depends on delivery-002 canvas/tools)

| Can Be Done In Parallel |
|------------------------|
| task-012, task-012b (independent — different deps) |
| task-013, task-015 (after respective list views) |

### delivery-004: Complete Editor — Import/Export + Full Sidebar

**Features:** 004 (Import/Export) + 003-remaining (Statistics, Map Properties, Active Tool Indicator)
**Depends on:** delivery-001, delivery-002, delivery-003
**Cumulative state:** Full editor with map import/export, validation, statistics, map properties — all features integrated

Build order:
1. feature-004 (Import/Export) — MapSerializer, import/export validation UI, detailed error list
2. feature-003-remaining (Full Sidebar) — biome statistics, tile counts, map properties panel, active tool indicator. Final integration glue.

This is the final delivery. After this, the editor is fully functional: open project → load/create map → paint with palette → edit resources/biomes → export valid JSON → unsaved changes protection.

**AC coverage:** AC1 (round-trip), AC3 (authoring), AC6 (export validation), AC9 (import validation) — all remaining ACs

#### Execution Graph

| Task | Depends On |
|------|-----------|
| task-017 | task-007, task-002 |
| task-018 | task-017, task-005 |
| task-019 | task-008, task-009, task-012, task-012b, task-014, task-018 |
| task-020 | task-018, task-019 |

| Can Be Done In Parallel |
|------------------------|
| (none — linear chain) |

### delivery-005: Editor Redesign — Foundation

**Features:** 010 (Editor Redesign) — Phases 1, 2, 3
**Depends on:** delivery-004 (complete editor must be shippable before restyling)
**Branch:** `feature/editor-redesign` (proposed — branched from `main` after feature/props-grassland merges)
**Cumulative state:** Editor has design token system, hierarchical domain sidebar (WORLD/PROPS/SYSTEMS/NARRATIVE/PROJECT), master-detail 3-column layout. All form logic (caps, CollisionShapes, MeshVariants) preserved intact.

Build order:
1. **Phase 1** — Port `:root` tokens + import Inter/IBM Plex Mono fonts. Replace ad-hoc colors/fonts with CSS custom properties. Reversible via deleting `tokens.css`.
2. **Phase 2** — Extract Sidebar module, define NAV array, port `.side-section` / `.nav-item` styles, swap sidebar markup. Existing flat nav stays wired until cutover.
3. **Phase 3** — Wrap existing prop editor, biome editor form logic in new `.master-detail` / `.master` / `.detail` / `.detail-preview` structure. Tests from feature-005/006 must all still pass.

**AC coverage:** AC12 (design system), AC13 (sidebar IA), AC14 (master-detail)

### delivery-006: Editor Cross-References

**Features:** 010 (Editor Redesign) — Phase 4
**Depends on:** delivery-005
**Cumulative state:** Detail preview column shows live cross-references. Selecting a biome reveals which chapters reference it and their tile counts; selecting a prop reveals which biomes drop it.

Build order:
1. Create `js/cross-refs.js` graph analyzer (scans `data/maps/*.json` + `data/biomes/*.tres`)
2. Wire preview panels in prop editor and biome editor
3. Optional: cache computation in server.py endpoint if client-side scan becomes slow as maps grow

**AC coverage:** AC15 (cross-references)

### delivery-007: Editor Quality-of-Life (optional)

**Features:** 010 (Editor Redesign) — Nice-to-haves
**Depends on:** delivery-006
**Cumulative state:** Command palette ⌘K, status bar with git/godot/route state, live hex preview widget, Playtest button that launches Godot, runtime tweaks panel for accent/density.

Build order (each ships independently):
1. Command Palette — port `src/command-palette.jsx` (169 LoC) to vanilla JS
2. Status Bar — bottom bar with unsaved/branch/route/hex/tool/tile-count
3. Hex Preview widget in Biome Editor detail column
4. Playtest button — server.py endpoint launches `godot --path <project>`
5. Tweaks Panel — runtime accent/density/layout toggles

## Delivery Progression

```
delivery-001: Infrastructure     → "The editor opens, loads my project, parses all files."
delivery-002: See & Paint         → "I can see my map and paint it!"
delivery-003: Data Editors        → "I can create and edit resources and biomes."
delivery-004: Ship It             → "I can import, export, and the editor is complete."
delivery-005: Redesign Foundation → "The editor looks professional — tokens, sidebar, master-detail."
delivery-006: Cross-References    → "I can see which chapters use this biome and which biomes drop this prop."
delivery-007: Quality-of-Life     → "⌘K, status bar, Playtest, tweaks — the editor is a joy to use."
```

Each delivery is testable standalone. Delivery-002 and delivery-003 can be built in parallel since they share only delivery-001 as a prerequisite.

## Notes

- **Feature-007 weight:** TresParser is complex (typed arrays, PackedStringArray, dict key styles, round-trip validation). During task breakdown, it should be its own task(s) separate from the app shell.
- **Parallel opportunity:** delivery-002 (canvas) and delivery-003 (editors) are independent — they could be built concurrently by different agents.
- **Hardcoded biome warning:** MapLoader only recognizes 5 biomes. Export validator should warn on custom biomes (documented in F-004 and F-006 SPECs).
- **Single HTML file constraint:** All code lives in one `tools/level-editor/index.html` — no build step, no dependencies.

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-04-03 | Plan created — 4 deliveries, 9 features. Proposal 1 (infra-first) selected over Proposal 2 (infra+canvas). | /aid-plan |
| 2026-04-03 | Task breakdown complete — 20 tasks across 4 deliveries. Execution graphs added. | /aid-detail |
| 2026-04-04 | Sub-hex grid retrofit note added to delivery-002 section. Task list and execution graph unchanged. | design change |
| 2026-04-04 | Unified props model retrofit note added to delivery-002 section. | design change |
| 2026-04-17 | Added feature-010 (Editor Redesign) + delivery-005/006/007 — port of Claude Design prototype (tokens, sidebar IA, master-detail, cross-refs, QoL nice-to-haves). Features count 9 → 10. | feature-010 approval |
