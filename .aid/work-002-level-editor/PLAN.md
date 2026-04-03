# Delivery Plan — work-002-level-editor

**Status:** Approved
**Created:** 2026-04-03
**Features:** 9 (all SPECs Ready)
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

**Key dependency notes:**
- F-007 (File Discovery) and F-008 (Command Infrastructure) are the two zero-dependency foundations
- F-003 (Palette & Sidebar) has the highest fan-in — it is the integration glue connecting nearly everything
- F-005 (Resource Editor) must precede F-006 (Biome Editor) because biome resource_table dropdown needs resource IDs
- F-004 (Import/Export) is independent of the .tres editors — only needs the HexGrid model + file handles

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

This is the visual payoff. After this delivery, the user can see a hex map rendered with correct biome colors, elevation overlays, cliff indicators, and can paint/edit it with all tools.

**AC coverage:** AC7 (undo/redo), partial AC3 (authoring)

#### Execution Graph

| Task | Depends On |
|------|-----------|
| task-007 | task-001 |
| task-008 | task-007, task-002 |
| task-009 | task-008, task-004 |
| task-010 | task-009 |
| task-011 | task-008, task-009, task-010 |

| Can Be Done In Parallel |
|------------------------|
| (none — linear chain) |

### delivery-003: Data Editors — Resource + Biome

**Features:** 005 (Resource Editor) + 006 (Biome Editor)
**Depends on:** delivery-001
**Cumulative state:** Full CRUD for ResourceDef and BiomeData .tres files, live biome color preview on map canvas

Build order:
1. feature-005 (Resource Editor) — list/edit/create/delete ResourceDef, .tres serialization
2. feature-006 (Biome Editor) — list/edit/create/delete BiomeData, resource table editor, live color preview

These two are independent of the hex canvas (delivery-002) but depend on TresParser from delivery-001. They can be built in parallel with delivery-002 if desired. F-005 must precede F-006 (biome resource_table dropdown needs resource IDs).

**AC coverage:** AC2 (.tres round-trip save), AC4 (resource CRUD), AC5 (biome CRUD)

#### Execution Graph

| Task | Depends On |
|------|-----------|
| task-012 | task-003, task-004 |
| task-013 | task-012 |
| task-014 | task-003, task-004, task-012 |
| task-015 | task-014 |
| task-016 | task-013, task-015 |

| Can Be Done In Parallel |
|------------------------|
| task-012, task-014 (after shared deps) |
| task-013, task-015 (after respective list views) |

### delivery-004: Complete Editor — Import/Export + Sidebar

**Features:** 004 (Import/Export) + 003 (Palette & Sidebar)
**Depends on:** delivery-001, delivery-002, delivery-003
**Cumulative state:** Full editor with map import/export, validation, palette sidebar, statistics, map properties — all features integrated

Build order:
1. feature-004 (Import/Export) — MapSerializer, MapValidator, import validation, export validation, new map creation
2. feature-003 (Palette & Sidebar) — biome/resource/structure palettes, active tool indicator, statistics, map properties. This is the integration glue — wires all editors together.

This is the final delivery. After this, the editor is fully functional: open project → load/create map → paint with palette → edit resources/biomes → export valid JSON → unsaved changes protection.

**AC coverage:** AC1 (round-trip), AC3 (authoring), AC6 (export validation), AC9 (import validation) — all remaining ACs

#### Execution Graph

| Task | Depends On |
|------|-----------|
| task-017 | task-007, task-002 |
| task-018 | task-017, task-005 |
| task-019 | task-008, task-009, task-012, task-014, task-018 |
| task-020 | task-018, task-019 |

| Can Be Done In Parallel |
|------------------------|
| (none — linear chain) |

## Delivery Progression

```
delivery-001: Infrastructure  → "The editor opens, loads my project, parses all files."
delivery-002: See & Paint      → "I can see my map and paint it!"
delivery-003: Data Editors     → "I can create and edit resources and biomes."
delivery-004: Ship It          → "I can import, export, and the editor is complete."
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
