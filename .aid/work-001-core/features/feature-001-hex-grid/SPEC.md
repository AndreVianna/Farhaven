# Hex Grid & World Generation

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F1, §9 AC1 | /aid-interview |
| 2026-03-30 | Data Model section written — hex tile, grid API, signals, serialization | /aid-specify |
| 2026-03-30 | Data Model fix: Crash Site uses Wood/Stone/Fiber, not "Scrap" (consistency) | /aid-specify |
| 2026-03-30 | Feature Flow section written — worldgen pipeline with post-processing | /aid-specify |
| 2026-03-30 | Layers & Components written — removed FogOverlay, committed to MultiMesh | /aid-specify |
| 2026-03-30 | Mobile Specs written — performance budget confirmed | /aid-specify |
| 2026-03-30 | Merged reveal_around + update_visibility → single update_fog method | /aid-specify (feature-002 feedback) |
| 2026-03-30 | Serialization keys: q/r → tile_col/tile_row for readability | /aid-specify (feature-002 feedback) |
| 2026-03-31 | update_fog() replaced by refresh_visibility(sources) — multi-source fog | /aid-specify (feature-007) |
| 2026-03-31 | Audit fixes applied (see delivery DETAIL.md) | /audit |
| 2026-03-31 | Redesign: requirements updated — SPEC needs reconciliation | /aid-interview |
| 2026-03-31 | SPEC reset — technical specification cleared for fresh start | /aid-specify --reset |
| 2026-03-31 | Data Model written — carried forward + anomaly field, no element_types | /aid-specify |
| 2026-03-31 | Feature Flow written — anomaly placement uses reachability BFS | /aid-specify |
| 2026-03-31 | Layers & Components written — carried forward unchanged | /aid-specify |
| 2026-03-31 | Mobile Specs written — carried forward unchanged | /aid-specify |
| 2026-04-01 | [PIVOT] Renderer: 5 MultiMesh per biome → single ArrayMesh with per-vertex color blending. 1 draw call. Scatter props deferred. | /design-pivot |
| 2026-04-01 | [PIVOT] Elevation 0-9 all biomes. 3-tier traversal (walk/jump/blocked). Hand-crafted maps via MapLoader (replaces WorldGenerator). | /design-pivot |
| 2026-04-01 | C1: HEX_SIZE=3.0 added to Constants table. C6: ELEVATION_STEP=0.5 added to Constants table. C2: Cliff faces moved from deferred to current scope — flat vertical quads, higher tile biome color × 0.6, same ArrayMesh (0 extra draw calls). I7: Elevation lightening (+5%/level) marked [TUNING_REQUIRED]. I2: Touch pixel estimate marked [TUNING_REQUIRED] for HEX_SIZE=3.0. M3: Cliff faces noted as 0 extra draw calls. Fog of War range: transitioning to circular world-unit area [TUNING_REQUIRED]. | /pivot-cascade |
| 2026-04-03 | Review fixes: HEX_SIZE/ELEVATION_STEP ownership notes, ResourceNode fields (offset, rotation_deg) added | /aid-specify review |
| 2026-04-04 | Sub-hex grid (19 sub-hexes per tile, SUB_HEX_SIZE=0.6). Unified props: tile.props[] replaces resource_nodes/structure/anomaly. Prop data structure added. Serialization updated. Signals kept for backward compat, now operate on props. | /arch-update |

## Source

- REQUIREMENTS.md §5 F1 (Hex Grid & World Generation)
- REQUIREMENTS.md §9 AC1 (Hex Grid acceptance criteria)
- REQUIREMENTS.md §10 P0 — Foundation

## Description

The game world is a hand-crafted hex-tile map loaded from JSON level files. Each chapter has a designed map of 200–300 tiles with three biome types (Grassland, Forest, Rocky), a Crash Site as the player's starting zone, and intentionally placed anomalies for narrative triggers. Tiles are hidden under fog of war until the player moves adjacent to them.

**[PIVOT] Maps are hand-crafted, not procedural.** A story-driven game needs authored level design — anomaly locations, elevation puzzles, biome flow, and narrative pacing are all intentional. MapLoader replaces WorldGenerator.

This is the foundational feature — everything else builds on top of the hex grid.

## User Stories

- As a player, I want a hand-crafted world that feels designed and intentional
- As a player, I want to see different biome types with distinct visual identities so I can plan where to explore
- As a player, I want fog of war so that exploration feels like discovery, not just walking
- As a player, I want elevation to create interesting terrain — gradual ramps, jumpable gaps, and impassable cliffs

## Priority

Must (P0 — Foundation)

## Acceptance Criteria

- [ ] Load Chapter 1 map from JSON → 200–300 tiles
- [ ] All 3 biomes + Crash Site present
- [ ] Crash Site at origin (0,0)
- [ ] Fog tiles not visible until player moves adjacent
- [ ] At least 1 anomaly tile placed in map data
- [ ] Elevation 0-9 per tile, 3-tier traversal rules enforced

## Save Integration

Save stores runtime delta over the base map: fog state per tile, resource depletion, structures. The base map is read-only JSON. Auto-save at dawn serializes runtime state via Godot FileAccess. Corrupt/missing save = reload base map.

---

## Technical Specification

### Data Model

Carried forward from pre-redesign spec (validated through 3 audit rounds) with one
targeted addition: anomaly tiles.

#### Coordinate System

Axial `(q, r)` stored as `Vector2i`. Cube `(q, r, s)` derived on the fly for
algorithms — never stored. Follows Red Blob Games recommendation.

#### Enums

```gdscript
enum Biome { CRASH_SITE, GRASSLAND, FOREST, ROCKY, WATER }
enum FogState { HIDDEN, REVEALED, VISIBLE }
```

- `HIDDEN` — never seen, not rendered
- `REVEALED` — seen before, rendered dimmed
- `VISIBLE` — currently in visibility range, fully rendered

#### HexTile (Resource)

Lightweight data object — one per tile, ~300 max. Extends `Resource`.

| Property | Type | Description |
|----------|------|-------------|
| `coords` | `Vector2i` | Axial `(q, r)` — immutable |
| `biome` | `Biome` | Biome enum value |
| `elevation` | `int` | 0–9 range, affects traversability (3-tier: walk/jump/blocked) |
| `fog_state` | `FogState` | Current visibility state |
| `props` | `Array[Prop]` | All props on this tile (resources, structures, anomalies, spawn points) |

**Unified props model.** The hex is a container; the prop type defines behavior.
Multiple structures per hex are allowed as long as their sub-hex footprints don't overlap.

**No `element_types` field.** Each system owns its own data:
- Flora/minerals: `tile.props.filter(p.category == &"resource")` — scanner (feature-003) queries this
- Fauna: FaunaManager (feature-010) tracks creatures by position — scanner queries FaunaManager
- Anomalies: `tile.props.filter(p.category == &"anomaly")` — owned here

HexTile says WHAT resources and anomalies exist. Scanner/catalog decides IF the player
knows about them. No dual tracking, no leaked responsibilities.

#### Prop (Resource)

Unified data object for everything placed on a tile: resources, structures, anomalies,
spawn points. The hex is a container; the prop's `type` and `category` define behavior.

| Property | Type | Description |
|----------|------|-------------|
| `type` | `StringName` | Prop identifier: `&"wood"`, `&"stone"`, `&"shelter"`, `&"anomaly_ch1_001"`, etc. |
| `sub_hex` | `Vector2i` | Axial `(sq, sr)` position within the parent tile's sub-hex grid |
| `category` | `StringName` | `&"resource"`, `&"structure"`, `&"anomaly"`, `&"spawn"` |
| `footprint` | `Array[Vector2i]` | Sub-hex coords this prop occupies (structures only; empty for resources/anomalies) |
| `rotation` | `float` | Degrees, converted to radians at render time |
| `remaining` | `int` | Gathers left before depletion (resources only; -1 for non-resources) |
| `max_amount` | `int` | For respawn reset (resources only; -1 for non-resources) |
| `tool_required` | `StringName` | `&""` = bare hands, `&"stone_axe"`, `&"stone_pickaxe"` (resources only) |
| `respawn_time` | `float` | Seconds until respawn after depletion (0 = no respawn; resources only) |

`respawn_time` is set from `ResourceRegistry` during map load. `sub_hex` and `rotation` are set from map JSON (or assigned by MapLoader for string-form resources).

**Category governs behavior:**
- `&"resource"` — gatherable. Uses `remaining`, `max_amount`, `tool_required`, `respawn_time`.
- `&"structure"` — built or map-placed. Uses `footprint` (which sub-hexes it occupies). `blocks_movement` is looked up from `structure_config[type]`.
- `&"anomaly"` — narrative trigger. Scanned by feature-003/011.
- `&"spawn"` — spawn point marker. Used by MapLoader.

#### Sub-Hex Coordinate System

Each main hex (6m diameter, HEX_SIZE=3.0 radius) contains a grid of 19 sub-hexes
(~1.2m diameter, SUB_HEX_SIZE=0.6 radius) arranged in a hex pattern of radius 2.
Sub-hexes use axial coordinates `(sq, sr)` relative to the parent tile center `(0, 0)`.

```
Sub-hex layout (radius 2, 19 cells):
         (-2,0) (-1,-1) (0,-2)
       (-2,1) (-1,0) (0,-1) (1,-2)
     (-2,2) (-1,1) (0,0) (1,-1) (2,-2)
       (-1,2) (0,1) (1,0) (2,-1)
         (0,2) (1,1) (2,0)
```

Props are placed at sub-hex positions within tiles. The main hex remains the unit
for movement, fog, biome, and elevation. Sub-hex positioning is for prop placement
granularity only.

#### Legacy ResourceNode (Removed)

**Replaced by Prop with `category == &"resource"`.** All fields from ResourceNode
are now on Prop. The `offset`/`rotation_deg` fields are replaced by `sub_hex`/`rotation`.

#### Elevation

All biomes use elevation 0–9. Elevation is set per-tile in the hand-crafted map data — no biome-based constraints.

| Biome | Typical Elevation | Character |
|-------|------------------|-----------|
| Crash Site | 0 | Flat, accessible. Resources: Wood, Stone, Fiber |
| Grassland | 0–3 | Open terrain, gentle hills |
| Forest | 0–4 | Moderate hills, undergrowth |
| Rocky | 3–9 | Highlands, plateaus, cliff barriers |
| Water | 0 | Always lowest |

*Ranges are design guidance, not constraints. The level designer places elevation freely.*

#### Traversal Rules (3-Tier)

```gdscript
enum TraversalType { WALK, JUMP, DROP, BLOCKED }
```

| Elevation Diff | Going Up (↑) | Going Down (↓) | Visual |
|---------------|--------------|----------------|--------|
| 0–1 | WALK | WALK | Smooth mesh transition |
| 2–3 | JUMP (~0.3s) | DROP (~0.2s) | Gap, no connecting mesh |
| 4+ | BLOCKED | BLOCKED | Cliff gap, future wall texture |

**Asymmetric gravity:** Dropping is faster than jumping (0.2s vs 0.3s) but both are auto-triggered — no player input. The player walks toward a jumpable gap and the character jumps/drops automatically.

**Fauna traversal:** Each fauna species has a `max_jump: int` attribute (see F-010). A fauna with `max_jump: 1` treats diff 2+ as BLOCKED. A fauna with `max_jump: 3` can traverse diff 2–3 gaps. `max_jump: -1` (sentinel) = flying, ignores all gaps. Mechanic implementation deferred — attribute defined now.

#### Biome Color Palette

Each biome has 2–3 color variations. The level designer assigns per-tile in the map JSON. Edge/corner vertices blend adjacent tile colors automatically.

| Biome | Base Colors | Character |
|-------|------------|-----------|
| CRASH_SITE | Warm brown, burnt sienna, dark earth | Scorched landing zone |
| GRASSLAND | Light green, olive, spring green | Open starter terrain |
| FOREST | Dark green, forest green, moss | Dense undergrowth |
| ROCKY | Gray, slate, charcoal | Highlands, barriers |
| WATER | Deep blue, teal, navy | Impassable water |

Colors are defined in BiomeData .tres files as `color_variations: Array[Color]` (2-3 entries). Elevation subtly lightens the color (higher = lighter, +5% per elevation level). **[TUNING_REQUIRED]** — with ELEVATION_STEP=0.5 and 10 levels the total lightening is 45%; may need reduction (e.g., +3%/level) once visual height range is tested.

**Scatter props** (post-MVP): Biome visual identity will come from decorative 3D props placed on hexes (grass tufts, rocks, bushes, flowers). These are NOT part of the hex mesh — they are separate MultiMesh instances managed by a future ScatterRenderer. Not specified or implemented until after delivery-006.

#### HexGrid (Node — autoload singleton)

Map container and sole public API. All cross-feature interaction goes through HexGrid.

**Storage:**

| Field | Type | Description |
|-------|------|-------------|
| `_tiles` | `Dictionary` | `Dictionary[Vector2i, HexTile]` — axial coords → tile |
| `_seed` | `int` | Generation seed for reproducibility |

**Constants:**

| Constant | Value | Description |
|----------|-------|-------------|
| `HEX_SIZE` | `3.0` | World-space radius of one hex (center to corner). All spatial calculations derive from this constant. Drives `axial_to_world`, `world_to_axial`, camera calibration, and player scale. **Note:** Lives on `HexMath` (not HexGrid) in the actual codebase — HexMath is the coordinate engine. |
| `SUB_HEX_SIZE` | `0.6` | World-space radius of one sub-hex. 19 sub-hexes per main hex (radius-2 hex grid). Used for prop placement granularity. `SUB_HEX_SIZE = HEX_SIZE / 5.0`. Lives on `HexMath`. |
| `ELEVATION_STEP` | `0.5` | World units of Y offset per elevation level. Total height range: 9 × 0.5 = 4.5 units. Drives cliff face heights, jump arc parameters, and vertical camera framing. **Note:** In code, `player.gd` uses `ELEVATION_SCALE` (same value, different name). |
| `WALK_MAX_DIFF` | `1` | Walk: smooth mesh, normal movement |
| `JUMP_MAX_DIFF` | `3` | Jump/Drop: gap, auto-animation. 4+ = BLOCKED (cliff) |

#### Core API

```gdscript
# Tile queries
func get_tile(coords: Vector2i) -> HexTile
func get_neighbors(coords: Vector2i) -> Array[Vector2i]
func get_tiles_in_range(center: Vector2i, radius: int) -> Array[Vector2i]
func distance(a: Vector2i, b: Vector2i) -> int

# Traversability — 3-tier rules:
#   biome == WATER → BLOCKED
#   elevation_diff 0-1 → WALK (smooth)
#   elevation_diff 2-3 → JUMP (up) / DROP (down) — auto-animation
#   elevation_diff 4+ → BLOCKED (cliff)
#   structure with blocks_movement: true → BLOCKED
func get_traversal(from: Vector2i, to: Vector2i) -> TraversalType
func is_passable(from: Vector2i, to: Vector2i) -> bool  # convenience: != BLOCKED
func get_elevation_diff(from: Vector2i, to: Vector2i) -> int

# Fog — multi-source, single pass (see feature-008 for full docs)
# Range system note: Fog of War reveal is transitioning from hex-distance (radius 2/3 hexes)
# to world-unit circular area (~3 inscribed hex radii ≈ 7.8 world units at HEX_SIZE=3.0).
# [TUNING_REQUIRED] — exact radius tuned during playtesting.
func refresh_visibility(sources: Array[Dictionary]) -> Array[Vector2i]

# Coordinate conversions
func axial_to_cube(coords: Vector2i) -> Vector3i
func axial_to_world(coords: Vector2i) -> Vector2
func world_to_axial(world_pos: Vector2) -> Vector2i
```

#### Signals — Cross-Feature Integration API

```gdscript
signal map_generated()
signal tile_revealed(coords: Vector2i)
signal tile_visibility_changed(coords: Vector2i, state: FogState)
signal tile_entered(coords: Vector2i)
signal tile_exited(coords: Vector2i)
signal resource_depleted(coords: Vector2i, resource_type: StringName)   # operates on props with category="resource"
signal resource_respawned(coords: Vector2i, resource_type: StringName)  # operates on props with category="resource"
signal tile_contents_changed(coords: Vector2i)  # reserved for future use
signal structure_placed(coords: Vector2i, structure_type: StringName)   # operates on props with category="structure"
signal structure_destroyed(coords: Vector2i, structure_type: StringName) # operates on props with category="structure"
```

**Ownership pattern:** HexGrid owns signals and emit methods. Downstream features call
HexGrid methods that update tile state and emit. No feature emits directly on HexGrid.

#### Serialization Format

```json
{
  "seed": 12345,
  "tiles": [
    {
      "tile_col": 0, "tile_row": 1,
      "biome": 2,
      "elevation": 1,
      "fog": 1,
      "props": [
        { "type": "wood", "sub_hex": [0, -1], "category": "resource", "remaining": 3, "max": 3, "tool": "" },
        { "type": "wood", "sub_hex": [1, 0], "category": "resource", "remaining": 3, "max": 3, "tool": "" },
        { "type": "shelter", "sub_hex": [0, 0], "category": "structure", "footprint": [[0,0],[-1,0],[1,0],[0,-1],[0,1],[-1,1],[1,-1]], "rotation": 0 }
      ]
    }
  ]
}
```

Code uses `q`/`r`. Serialized JSON uses `tile_col`/`tile_row` for readability.
Props use `sub_hex: [sq, sr]` for sub-hex position. Structure props include
`footprint` as array of `[sq, sr]` pairs.

### Feature Flow

#### Map Loading Pipeline

**[PIVOT] Hand-crafted maps replace procedural generation.** MapLoader reads a JSON
level file and populates HexGrid. WorldGenerator is removed.

```
MAP FILE (res://data/maps/ch1.json)
  │
  ├─ Step 1: Parse JSON
  │     Read and validate chapter_id, name, spawn coords, tiles dictionary.
  │
  ├─ Step 2: Create HexTile objects
  │     For each tile entry: create HexTile Resource, set coords/biome/elevation.
  │     Populate props[] from tile's "props" array (or from legacy "resources"/"anomaly"
  │     fields via backward-compat conversion). Each prop gets a Prop Resource with
  │     type, sub_hex, category, and category-specific fields.
  │
  ├─ Step 3: Register tiles in HexGrid
  │     Add each HexTile to HexGrid._tiles dictionary.
  │
  ├─ Step 4: Validate map
  │     ✓ Tile count 200–300
  │     ✓ All required biomes present (GRASSLAND, FOREST, ROCKY, CRASH_SITE)
  │     ✓ Spawn tile exists and is CRASH_SITE
  │     ✓ At least 1 anomaly tile present
  │     ✓ All elevations in range 0–9
  │     ✓ Reachability BFS from spawn: every non-WATER tile reachable
  │       (using is_passable — includes WALK and JUMP/DROP tiles)
  │     On failure → error log with specific issue. Do not crash.
  │
  ├─ Step 5: Initialize fog
  │     All → HIDDEN. Spawn tile + immediate neighbors → VISIBLE.
  │
  └─ Step 6: Emit map_generated()
```

#### Map File Format

```json
{
  "chapter_id": "ch1",
  "name": "Crash Landing",
  "spawn": [0, 0],
  "tiles": {
    "0,0":   { "biome": "crash_site", "elevation": 0 },
    "1,0":   { "biome": "crash_site", "elevation": 0, "props": [
      { "type": "wood", "sub_hex": [0, -1], "category": "resource" },
      { "type": "stone", "sub_hex": [1, 0], "category": "resource" }
    ]},
    "0,1":   { "biome": "grassland",  "elevation": 1 },
    "-3,5":  { "biome": "rocky",      "elevation": 6, "props": [
      { "type": "anomaly_ch1_001", "sub_hex": [0, 0], "category": "anomaly" }
    ]},
    "2,-1":  { "biome": "water",      "elevation": 0 }
  }
}
```

**Keys:** `"q,r"` axial coordinates as strings.
**biome:** String matching Biome enum name (lowercase).
**elevation:** Integer 0–9.
**props:** Optional array of prop objects. Each has `type`, `sub_hex` (axial coords
within the sub-hex grid), and `category`. Resource props use ResourceRegistry for
remaining/max_amount/tool_required. Structure props include `footprint`.
MapLoader assigns sub_hex positions (or randomizes them for legacy string-form resources).
**Missing tile = off-map.** Not rendered, not accessible.

**The map file is read-only at runtime.** Save data stores the runtime delta
(fog state, resource depletion, structures placed). Loading a save applies
deltas on top of the base map.

#### Design Rationale

**Hand-crafted over procedural:** A curiosity/story-driven game needs authored
pacing. The anomaly goes on the plateau because the designer put it there —
not because an algorithm rolled dice.

**JSON format:** Simple, human-editable, diffable in git. 200–300 tile entries
is manageable in a text editor. Future: visual editor tool (Godot plugin or
standalone) can export to this format.

**Reachability validation:** Even hand-crafted maps get validated. A level design
error that makes the anomaly unreachable should fail loudly during development,
not silently at runtime.

**Resource tables are data-driven:** BiomeData .tres files define what resources
exist per biome and their properties. Map files list props with types and sub-hex
positions — MapLoader looks up config from BiomeData/ResourceRegistry.

### Layers & Components

Carried forward from pre-redesign spec — unchanged by the redesign.

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       └─ HexGridRenderer (Node3D)
            └─ MeshInstance3D [single ArrayMesh — entire hex grid]
```

No FogOverlay. HIDDEN = vertices culled (degenerate triangle). REVEALED = dimmed vertex color. VISIBLE = full vertex color.

**[PIVOT] Single mesh replaces 5 MultiMeshInstance3D.** Per-vertex color blending creates smooth biome transitions at edges and corners. One draw call for the entire grid.

#### Autoload

```
HexGrid (Node) — Project Settings → Autoload
```

Pure data + logic. No visuals. Accessible globally.

#### File Structure

```
scripts/
  hex/
    hex_grid.gd           # Autoload — map container, API, signals
    hex_tile.gd           # Resource — tile data (props[] replaces resource_nodes/structure/anomaly)
    prop.gd               # Resource — unified prop (resource, structure, anomaly, spawn)
    hex_math.gd           # Static utility (class_name HexMath) — includes sub-hex coordinate helpers
    map_loader.gd         # RefCounted — loads JSON level files, populates HexGrid
    biome_data.gd         # Resource — per-biome config (colors, resource tables)

scenes/
  world/
    hex_grid_renderer.gd  # Node3D — single ArrayMesh, signal-driven
    hex_grid_renderer.tscn # Scene — single MeshInstance3D child

data/
  biomes/
    crash_site.tres, grassland.tres, forest.tres, rocky.tres, water.tres
  maps/
    ch1.json              # Chapter 1 hand-crafted level data

shaders/
  hex_tile.gdshader       # Per-vertex color pass-through + optional fog/highlight modulation
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `hex_grid.gd` | Data ownership, public API, signals. Owns `_tiles` Dictionary. | `hex_tile.gd`, `hex_math.gd` |
| `hex_math.gd` | Pure static functions: axial↔cube↔world, distance, neighbors, rings. No state. | Nothing |
| `map_loader.gd` | Loads JSON level file, creates HexTiles, populates HexGrid, validates. RefCounted — freed after loading. | `hex_grid.gd`, `hex_math.gd`, `biome_data.gd` |
| `biome_data.gd` | Data-only Resource: color variations, resource tables, material ref. | Nothing |
| `hex_grid_renderer.gd` | Single ArrayMesh with per-vertex color blending. Builds mesh on map_generated. Updates vertex colors on fog changes. Signal-driven, no per-frame queries. 1 draw call. | `hex_grid.gd` (signals only) |
| `hex_tile.gdshader` | Fog tinting (dim/full) + highlight channel for placement mode. | Nothing (GPU-side) |

#### Rendering Architecture — Single ArrayMesh

**[PIVOT]** One draw call for the entire grid. Replaces 5 MultiMeshInstance3D.

**Mesh construction (on `map_generated`):**
1. For each hex tile, generate 7 vertices: 1 center + 6 corners
2. Center vertex color = biome color variation (from BiomeData, noise-selected)
3. Corner vertex color = average of the 2–3 hex tiles sharing that corner
4. Edge midpoints (if using subdivided hex): average of 2 adjacent tiles
5. Assemble triangles (6 per hex, fan from center)
6. Y position = elevation offset
7. Hidden tiles: degenerate triangles (zero area) or skip entirely

**Fog rendering:**
- HIDDEN: vertices excluded from mesh (or degenerate) — not rendered
- REVEALED: vertex colors darkened (multiply by ~0.4)
- VISIBLE: full vertex colors

**Fog updates (on `tile_visibility_changed`):**
- Rebuild ONLY affected hex vertices (the changed tile + its neighbors for smooth edge updates)
- Do NOT rebuild entire mesh — partial vertex buffer update via `SurfaceTool` or direct `mesh.surface_get_arrays()` modification

**Highlight (for building placement):**
- `highlight_tiles(coords, color)`: temporarily override vertex colors for specified tiles
- `clear_highlights()`: restore original colors
- Zero additional draw calls

**Biome transitions are automatic.** Because corner vertices average their neighbors' colors, a Grassland hex next to a Forest hex will have green-to-dark-green gradient at the shared edge. No explicit transition logic needed. The mesh topology handles it.

**Elevation and vertex sharing:**
- Same elevation → shared corner/edge vertices → blended color → smooth transition
- Different elevation → each hex owns its own vertices at its own Y → hard cliff edge
- This creates natural visual hierarchy: color = biome, hard edge = elevation change
**Cliff face geometry:** Flat vertical quads rendered between adjacent hexes at different elevations. Uses the higher tile's biome color × 0.6. Added as additional triangles in the same ArrayMesh build loop — **zero extra draw calls**. Cliff quad height = `ELEVATION_STEP × elevation_diff` world units. Implemented in task-004 alongside floor tile geometry.

**Anomaly visual markers are NOT owned by HexGridRenderer.** Anomaly rendering
(❓ icons, scan progress, revealed state) is owned by feature-003 (scanner/catalog)
or feature-011 (journal). HexGridRenderer renders terrain only.

#### Architectural Decisions

- **HexGrid as autoload:** Global access without node references.
- **HexMath as static class_name:** Pure math, no singleton lifecycle.
- **MapLoader as RefCounted:** Run once, load map data, garbage collected.
- **BiomeData as .tres:** Data-driven tuning without code changes.

### Mobile Specs

Carried forward from pre-redesign — unchanged.

#### Performance Budget — Hex Grid Share

| Metric | Budget (whole game) | Hex Grid Usage | Remaining |
|--------|-------------------|----------------|-----------|
| Draw calls | <100/frame | ~1 (single ArrayMesh, cliff faces included) | ~99 |
| Memory | <200MB | <1MB (tiles + mesh + materials) | ~199MB |
| Tris per object | <500 | <20 (hex floor) + cliff quads (2 tris per cliff edge) | — |

**Cliff faces share the ArrayMesh draw call** — zero additional draw calls beyond the single HexGridRenderer call.

#### Map Loading Cost

- Parse JSON + create 200–300 HexTile Resources + reachability BFS validation
- Single-threaded GDScript, CPU-bound
- Expected <100ms on mid-range 2022+ devices. One-time startup cost. Faster than
  procedural generation (no noise, no cluster post-processing).

#### Per-Frame Cost

Zero. Renderer is event-driven. Worst case per move: ~12 instance updates
(visibility radius 2 = ~12 tiles). Negligible.

#### Touch Input Geometry

- `world_to_axial()`: O(1) per touch (Red Blob Games nearest-hex algorithm)
- Hex screen size at HEX_SIZE=3.0 + camera `Vector3(0, 12, 8)`: **[TUNING_REQUIRED]** — previous estimate (~54-72px) was for HEX_SIZE=1.0. Verify after camera calibration. Target: above 48dp minimum.

#### Platform Differences

None. Pure Godot rendering. iOS and Android identical.
