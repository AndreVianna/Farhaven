# task-011b: Ghost Grid and Empty-Cell Interaction

**Type:** IMPLEMENT
**Delivery:** delivery-002
**Depends on:** task-008 (HexCanvas), task-009 (ToolManager + painting tools)
**Status:** Done
**Grade:** A
**Created:** 2026-04-04

## Description

Add ghost grid rendering and empty-cell interaction to the hex canvas. Ghost hexes are faint outlines drawn at all empty positions adjacent to existing tiles. They provide visual affordance for map expansion and respond to hover and tool interactions. Painting on a ghost cell creates a real tile and the ghost set updates dynamically.

## Scope

1. **Ghost set computation** in HexCanvas.render():
   - After clearing canvas, before drawing tiles, compute the set of all empty hex positions that are neighbors of at least one existing tile.
   - Use `HexMath.getNeighbors()` for each existing tile; collect positions where `grid.hasTile(q, r) === false`.
   - Deduplicate via a Set keyed on `"q,r"`.

2. **Ghost hex rendering** (`_drawGhostHex(q, r)`):
   - Draw hex polygon with faint fill (`rgba(255,255,255,0.08)`) and subtle stroke (`rgba(255,255,255,0.15)`, 1px).
   - Drawn before real tiles so they appear behind.

3. **Ghost hover detection**:
   - `screenToHex()` already converts any screen position to a hex coordinate — no change needed.
   - In `_onMouseMove`, when hoveredHex is not a real tile but IS in the ghost set, show hover highlight and a minimal tooltip: "(q, r) — empty".
   - Ghost hover highlight uses a different style (e.g., `rgba(255,255,255,0.1)` fill).

4. **Tool interaction on ghost cells**:
   - `SetBiomeCommand` already creates a tile if it doesn't exist — no change needed.
   - `SetElevationCommand` already creates a tile if it doesn't exist (fixed in code review) — no change needed.
   - `ElevationBrush._applyToHex()` currently returns early if `!tile` — must be updated to allow painting on empty cells.
   - Other tools (ResourcePlacer, StructurePlacer, etc.) should also work on ghost cells where it makes sense, or silently no-op.

5. **Dynamic ghost updates**:
   - Ghost set is recomputed every render frame (it depends on `grid.tiles` which changes as tiles are added/removed).
   - No caching needed — iterating neighbors of 300 tiles (checking ~1800 neighbor positions) is negligible for Canvas2D.

## Acceptance Criteria

- [ ] Given a loaded map, ghost hex outlines are visible at all empty positions adjacent to existing tiles
- [ ] Given a ghost hex, hovering shows a subtle highlight and tooltip with "(q, r) — empty"
- [ ] Given biome brush, painting on a ghost cell creates a new tile with the selected biome
- [ ] Given elevation brush, painting on a ghost cell creates a new tile with the target elevation
- [ ] Given a newly created tile, the ghost grid updates immediately to include its new empty neighbors
- [ ] Given a tile deleted with DeleteHexTool, the ghost grid updates immediately (deleted position becomes ghost if still adjacent to other tiles)
- [ ] Ghost hexes do not interfere with existing tile rendering (drawn behind)
- [ ] Performance: no visible lag with 300+ existing tiles (ghost set ~1800 positions)

## Files to Modify

- `tools/level-editor/index.html`:
  - HexCanvas class: add `_computeGhostSet()`, `_drawGhostHex()`, update `render()`, update hover logic
  - ElevationBrush: remove early return on `!tile` (allow painting on empty cells)
- `tools/level-editor/test-unit.mjs`: add ghost grid unit tests

## Tests

- Ghost set computation: given a single tile at (0,0), ghost set contains exactly the 6 neighbors
- Ghost set computation: given two adjacent tiles, ghost set does not include either tile, and shared neighbors are not duplicated
- Ghost set computation: given an empty grid, ghost set is empty
- Hover on ghost cell: tooltip shows "(q, r) — empty"
- BiomeBrush on ghost cell: tile is created with correct biome
- ElevationBrush on ghost cell: tile is created with correct elevation
