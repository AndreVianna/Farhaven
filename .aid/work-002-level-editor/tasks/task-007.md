# task-007: HexMath Module and HexGrid Model

**Type:** IMPLEMENT

**Source:** feature-001-hex-canvas -> delivery-002

**Depends on:** task-001

**Scope:**
- Implement `HexMath` module with all static utility functions matching Farhaven's `hex_math.gd`:
  - `axialToPixel(q, r)` -- flat-top, HEX_SIZE = 40px visual scale
  - `pixelToAxial(x, y)` -- inverse with cube rounding
  - `cubeRound(fq, fr)` -- fractional axial to nearest integer hex
  - `getNeighbors(q, r)` -- 6 flat-top axial directions
  - `distance(q1, r1, q2, r2)` -- hex distance
  - `hexCorners(cx, cy, size)` -- 6 corner points for flat-top hex
  - `getEdgeIndex(q1, r1, q2, r2)` -- edge index 0-5 between adjacent hexes
- Implement `HexGrid` class:
  - `meta` object (chapter_id, name, spawn)
  - `tiles` as `Map<string, TileData>` keyed by `"q,r"`
  - Methods: `getKey()`, `getTile()`, `setTile()`, `deleteTile()`, `hasTile()`, `getAllTiles()`, `clear()`
  - `onChange` callback hook for rendering subscription
- Define `TileData` structure: biome, elevation, structure, anomaly, resources array
- Define `ResourceInstance` structure: type, x, y, rotation
- Define `Camera` structure: offsetX, offsetY, zoom (clamped 0.2-3.0)

**Acceptance Criteria:**
- [ ] `HexMath.axialToPixel()` and `pixelToAxial()` are inverse operations (round-trip for integer coords)
- [ ] `HexMath.getNeighbors()` returns exactly 6 neighbors with correct flat-top axial directions
- [ ] `HexMath.cubeRound()` correctly snaps fractional coordinates to nearest hex
- [ ] `HexMath.hexCorners()` returns 6 points forming a valid flat-top hexagon
- [ ] `HexGrid.tiles` correctly stores and retrieves tile data by "q,r" key
- [ ] `HexGrid.onChange` callback fires on `setTile()` and `deleteTile()`
- [ ] All formulas match the game's `hex_math.gd` (axial coords, flat-top orientation)
- [ ] All code in `tools/level-editor/index.html`
