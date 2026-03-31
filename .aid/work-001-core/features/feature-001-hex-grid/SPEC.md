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

## Source

- REQUIREMENTS.md §5 F1 (Hex Grid & World Generation)
- REQUIREMENTS.md §9 AC1 (Hex Grid acceptance criteria)
- REQUIREMENTS.md §10 P0 — Foundation

## Description

The game world is a procedurally generated hex-tile map using axial/cube coordinates. Each playthrough creates a unique map of 200–300 tiles with three biome types (Grassland, Forest, Rocky) distributed via weighted rules and adjacency constraints, plus a scripted Crash Site near center as the player's starting zone. Tiles are hidden under fog of war until the player moves adjacent to them. At least one anomaly tile is placed per map for narrative triggers (scanner/catalog system).

This is the foundational feature — everything else builds on top of the hex grid.

## User Stories

- As a player, I want each playthrough to generate a unique map so that exploration feels fresh every time
- As a player, I want to see different biome types with distinct visual identities so I can plan where to explore
- As a player, I want fog of war so that exploration feels like discovery, not just walking

## Priority

Must (P0 — Foundation)

## Acceptance Criteria

- [ ] Generate 3 different maps → all have 200–300 tiles
- [ ] All 3 biomes + Crash Site present in every map
- [ ] Crash Site within 3 hexes of center
- [ ] No two adjacent tiles with same biome exceed cluster of 5
- [ ] Fog tiles not visible until player moves adjacent
- [ ] At least 1 anomaly tile placed per map

## Save Integration

This feature introduces the first save data: hex grid layout (tile positions, biome types, fog state). Auto-save at dawn serializes grid state to JSON via Godot FileAccess. Corrupt/missing save = fresh start without crash.

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
| `elevation` | `int` | 0–5 range, affects traversability |
| `fog_state` | `FogState` | Current visibility state |
| `structure` | `StringName` | Built structure (`&""` = empty) |
| `resource_nodes` | `Array[ResourceNode]` | Gatherable resources on this tile |
| `anomaly` | `StringName` | Anomaly ID (`&""` = none). Biome-independent. Scanned to trigger narrative (feature-003/011). |

**One structure per tile (MVP rule).** Deliberate design constraint.

**No `element_types` field.** Each system owns its own data:
- Flora/minerals: `tile.resource_nodes[].type` — scanner (feature-003) queries this
- Fauna: FaunaManager (feature-010) tracks creatures by position — scanner queries FaunaManager
- Anomalies: `tile.anomaly` — owned here

HexTile says WHAT resources and anomalies exist. Scanner/catalog decides IF the player
knows about them. No dual tracking, no leaked responsibilities.

#### ResourceNode (Resource)

| Property | Type | Description |
|----------|------|-------------|
| `type` | `StringName` | `&"wood"`, `&"stone"`, `&"berries"`, `&"fiber"`, `&"ore"`, `&"crystal"` |
| `remaining` | `int` | Gathers left before depletion |
| `max_amount` | `int` | For respawn reset |
| `tool_required` | `StringName` | `&""` = bare hands, `&"stone_axe"`, `&"stone_pickaxe"` |

Feature-004 (auto-interaction) extends with `respawn_time: float`.

#### Elevation Ranges by Biome

| Biome | Elevation Range | Character |
|-------|----------------|-----------|
| Crash Site | 0 | Flat, accessible. Resources: Wood, Stone, Fiber |
| Grassland | 0–1 | Flat starter terrain |
| Forest | 0–2 | Gentle hills |
| Rocky | 2–5 | Highlands, cliff barriers |
| Water | 0 | Always lowest |

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
| `MAX_ELEVATION_DIFF` | `1` | Max traversable elevation difference |

#### Core API

```gdscript
# Tile queries
func get_tile(coords: Vector2i) -> HexTile
func get_neighbors(coords: Vector2i) -> Array[Vector2i]
func get_tiles_in_range(center: Vector2i, radius: int) -> Array[Vector2i]
func distance(a: Vector2i, b: Vector2i) -> int

# Traversability — MVP rules:
#   biome == WATER → impassable
#   elevation_diff > MAX_ELEVATION_DIFF → impassable
#   structure with blocks_movement: true → impassable (Shelter/Torch walkable)
func is_passable(from: Vector2i, to: Vector2i) -> bool
func get_elevation_diff(from: Vector2i, to: Vector2i) -> int

# Fog — multi-source, single pass (see feature-008 for full docs)
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
signal resource_depleted(coords: Vector2i, resource_type: StringName)
signal resource_respawned(coords: Vector2i, resource_type: StringName)
signal tile_contents_changed(coords: Vector2i)  # reserved for future use
signal structure_placed(coords: Vector2i, structure_type: StringName)
signal structure_destroyed(coords: Vector2i, structure_type: StringName)
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
      "structure": "",
      "anomaly": "",
      "resources": [
        { "type": "wood", "remaining": 3, "max": 3, "tool": "" }
      ]
    }
  ]
}
```

Code uses `q`/`r`. Serialized JSON uses `tile_col`/`tile_row` for readability.

### Feature Flow

#### World Generation Pipeline

Carried forward from pre-redesign (Steps 1–7, 10–11 unchanged). New: reachability
BFS before anomaly placement (Step 8), updated validation (Step 9).

```
SEED (int — random or from save file)
  │
  ├─ Step 1: Place Crash Site
  │     Tiles at (0,0) + neighbors (radius ~1-2), Biome = CRASH_SITE, elevation = 0
  │
  ├─ Step 2: Expand map ring-by-ring (BFS from center)
  │     Target 200–300 tiles. Connected, roughly circular — no islands.
  │
  ├─ Step 3: Assign biomes via noise
  │     FastNoiseLite, distance-weighted: inner → Grassland, mid → Forest, outer → Rocky.
  │
  ├─ Step 4: Place water tile clusters
  │     Algorithm TBD at implementation. Goal: chokepoints between biome regions.
  │
  ├─ Step 5: Post-process biome clusters
  │     Flood-fill, swap edge tiles if cluster > 5. Deterministic, O(n).
  │
  ├─ Step 6: Generate elevation
  │     Noise clamped to biome ranges. Crash Site → 0, Water → 0.
  │
  ├─ Step 7: Populate resource nodes
  │     Per-biome tables from BiomeData .tres. 0–3 nodes per tile.
  │
  ├─ Step 8: Compute reachability + place anomalies
  │     8a. Run BFS from Crash Site using is_passable() rules.
  │         Produces _reachable_tiles: Set[Vector2i] — all tiles the player
  │         can actually walk to from Crash Site.
  │     8b. Place anomaly from reachable set:
  │         - Filter _reachable_tiles: ring distance >= 70% of max ring distance
  │         - Exclude tiles with structures
  │         - Pick randomly from candidates
  │         - Set tile.anomaly = &"anomaly_ch1_001"
  │         - Chapter 1 = 1 anomaly. Architecture supports N per chapter.
  │     Anomaly is reachable BY CONSTRUCTION — no wasted retries.
  │
  ├─ Step 9: Validate map
  │     ✓ Tile count 200–300
  │     ✓ All required biomes present (GRASSLAND, FOREST, ROCKY, CRASH_SITE)
  │     ✓ Crash Site within 3 hexes of center
  │     ✓ Cluster constraint met (guaranteed by Step 5, double-check)
  │     ✓ Reachability: at least one tile of each non-WATER biome in _reachable_tiles
  │     ✓ Anomaly placed and reachable (defensive assertion — guaranteed by Step 8)
  │     On failure → re-seed, retry (max 10 attempts).
  │     Retries should be rare — cluster post-processing + reachability-based
  │     anomaly placement eliminate most failure modes.
  │
  ├─ Step 10: Initialize fog
  │     All → HIDDEN. Crash Site + immediate neighbors → VISIBLE.
  │
  └─ Step 11: Emit map_generated()
```

#### Design Rationale

**Ring-by-ring expansion:** Connected by construction — no islands, no gaps.

**Post-processing over rejection-retry for clusters:** Deterministic fix, O(n).
Retry reserved for the harder reachability constraint.

**Reachability BFS before anomaly placement:** The BFS is already needed for
Step 9 validation. Computing it once in Step 8a and reusing the set for both
anomaly placement (8b) and validation (9) avoids redundant work and guarantees
the anomaly is always reachable — no map rejection for anomaly isolation.

**Anomaly at 70% distance:** Player must explore most of the map before finding it.
Natural Chapter 1 arc: crash → explore/scan/gather/build → discover anomaly far out →
narrative reward. Not trivially close to start, but guaranteed reachable.

**Resource tables are data-driven:** BiomeData .tres files, not hardcoded.

### Layers & Components

Carried forward from pre-redesign spec — unchanged by the redesign.

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       └─ HexGridRenderer (Node3D)
            ├─ MultiMeshInstance3D [CRASH_SITE]
            ├─ MultiMeshInstance3D [GRASSLAND]
            ├─ MultiMeshInstance3D [FOREST]
            ├─ MultiMeshInstance3D [ROCKY]
            └─ MultiMeshInstance3D [WATER]
```

No FogOverlay. HIDDEN = not rendered. REVEALED = dimmed via shader. VISIBLE = full.

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
    hex_tile.gd           # Resource — tile data
    resource_node.gd      # Resource — gatherable resource on a tile
    hex_math.gd           # Static utility (class_name HexMath)
    world_generator.gd    # RefCounted — generation pipeline (Steps 1–11)
    biome_data.gd         # Resource — per-biome config

scenes/
  world/
    hex_grid_renderer.gd  # Node3D — MultiMesh management, signal-driven
    hex_grid_renderer.tscn # Scene — 5 MultiMeshInstance3D children

data/
  biomes/
    crash_site.tres, grassland.tres, forest.tres, rocky.tres, water.tres

shaders/
  hex_tile.gdshader       # Per-instance fog tinting + highlight channel
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `hex_grid.gd` | Data ownership, public API, signals. Owns `_tiles` Dictionary. | `hex_tile.gd`, `hex_math.gd` |
| `hex_math.gd` | Pure static functions: axial↔cube↔world, distance, neighbors, rings. No state. | Nothing |
| `world_generator.gd` | Generation pipeline (Steps 1–11). RefCounted — freed after generation. | `hex_grid.gd`, `hex_math.gd`, `biome_data.gd` |
| `biome_data.gd` | Data-only Resource: resource tables, elevation range, cluster weight, material ref. | Nothing |
| `hex_grid_renderer.gd` | 5 MultiMeshInstance3D (one per biome). Signal-driven updates. No per-frame queries. | `hex_grid.gd` (signals only) |
| `hex_tile.gdshader` | Fog tinting (dim/full) + highlight channel for placement mode. | Nothing (GPU-side) |

#### Rendering Architecture — MultiMesh

~5 draw calls for the entire grid. Per-instance custom data controls fog tint and
highlight. Instance transforms encode position + elevation Y offset. HIDDEN tiles at
zero scale. Updates on `tile_revealed`/`tile_visibility_changed` signals.

`highlight_tiles(coords, color)` / `clear_highlights()` API for building placement
mode (feature-009). Uses the shader's highlight channel — zero additional draw calls.

**Anomaly visual markers are NOT owned by HexGridRenderer.** Anomaly rendering
(❓ icons, scan progress, revealed state) is owned by feature-003 (scanner/catalog)
or feature-011 (journal). HexGridRenderer renders terrain only.

#### Architectural Decisions

- **HexGrid as autoload:** Global access without node references.
- **HexMath as static class_name:** Pure math, no singleton lifecycle.
- **WorldGenerator as RefCounted:** Run once, produce data, garbage collected.
- **BiomeData as .tres:** Data-driven tuning without code changes.

### Mobile Specs

Carried forward from pre-redesign — unchanged.

#### Performance Budget — Hex Grid Share

| Metric | Budget (whole game) | Hex Grid Usage | Remaining |
|--------|-------------------|----------------|-----------|
| Draw calls | <100/frame | ~5 (one MultiMesh per biome) | ~95 |
| Memory | <200MB | <1MB (tiles + MultiMesh + mesh + materials) | ~199MB |
| Tris per object | <500 | <20 (hex mesh) | — |

#### World Generation Cost

- 300 tiles x noise + cluster post-processing + reachability BFS + A* validation
- Single-threaded GDScript, CPU-bound
- Expected <200ms on mid-range 2022+ devices. One-time startup cost.

#### Per-Frame Cost

Zero. Renderer is event-driven. Worst case per move: ~12 instance updates
(visibility radius 2 = ~12 tiles). Negligible.

#### Touch Input Geometry

- `world_to_axial()`: O(1) per touch (Red Blob Games nearest-hex algorithm)
- ~54-72px per hex at 1080x1920 portrait. Above 48dp minimum.

#### Platform Differences

None. Pure Godot rendering. iOS and Android identical.
