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

## Source

- REQUIREMENTS.md §5 F1 (Hex Grid & World Generation)
- REQUIREMENTS.md §9 AC1 (Hex Grid acceptance criteria)
- REQUIREMENTS.md §10 P0 — Foundation

## Description

The game world is a procedurally generated hex-tile map using axial/cube coordinates. Each playthrough creates a unique map of 200–300 tiles with three biome types (Grassland, Forest, Rocky) distributed via weighted rules and adjacency constraints, plus a scripted Crash Site near center as the player's starting zone. Tiles are hidden under fog of war until the player moves adjacent to them.

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

## Save Integration

This feature introduces the first save data: hex grid layout (tile positions, biome types, fog state). Auto-save at dawn serializes grid state to JSON via Godot FileAccess. Corrupt/missing save = fresh start without crash.

---

## Technical Specification

### Data Model

#### Coordinate System

Axial coordinates `(q, r)` stored as `Vector2i`. Cube coordinates `(q, r, s)` where
`s = -q - r` are derived on the fly for algorithms (distance, range, rotation) — never
stored. This follows Red Blob Games' recommendation.

#### Enums

```gdscript
enum Biome { CRASH_SITE, GRASSLAND, FOREST, ROCKY, WATER }
enum FogState { HIDDEN, REVEALED, VISIBLE }
```

- `HIDDEN` — never seen, not rendered (or rendered as fog)
- `REVEALED` — seen before, rendered dimmed (player has moved away)
- `VISIBLE` — currently adjacent to player, fully rendered

#### HexTile (Resource)

Lightweight data object — one per tile, ~300 instances max. Extends `Resource` for type
safety and clean property access. Not a Node (no scene tree overhead).

| Property | Type | Description |
|----------|------|-------------|
| `coords` | `Vector2i` | Axial `(q, r)` — immutable after creation |
| `biome` | `Biome` | Biome enum value |
| `elevation` | `int` | 0–5 range, affects traversability |
| `fog_state` | `FogState` | Current visibility state |
| `structure` | `StringName` | What's built here (`&""` = empty) |
| `resource_nodes` | `Array[ResourceNode]` | Gatherable resources on this tile |

**One structure per tile (MVP rule).** A hex can hold at most one structure (Workbench,
Shelter, Wall, etc.). This is a deliberate design constraint, not a data model limitation.
If future work needs multiple structures per tile, `structure: StringName` becomes
`structures: Array[StringName]` — but for MVP the singular field enforces the rule at
the data level.

#### ResourceNode (Resource)

| Property | Type | Description |
|----------|------|-------------|
| `type` | `StringName` | `&"wood"`, `&"stone"`, `&"berries"`, `&"fiber"`, `&"ore"`, `&"crystal"` |
| `remaining` | `int` | Gathers left before depletion |
| `max_amount` | `int` | For respawn reset |
| `tool_required` | `StringName` | `&""` = bare hands, `&"stone_axe"`, `&"stone_pickaxe"` |

Feature-003 extends ResourceNode with `respawn_time: float` (seconds until respawn after depletion).

#### Elevation Ranges by Biome

Worldgen assigns elevation using a noise layer (`FastNoiseLite`). Biome type constrains
the elevation range:

| Biome | Elevation Range | Character |
|-------|----------------|-----------|
| Crash Site | 0 | Always flat, always accessible. Resources: small amounts of Wood, Stone, Fiber (enough to build first Workbench) |
| Grassland | 0–1 | Flat plains, safe starter terrain |
| Forest | 0–2 | Gentle hills |
| Rocky | 2–5 | Highlands, cliff edges create natural barriers |
| Water | 0 | Always lowest level |

#### HexGrid (Node — autoload singleton)

The map container and sole public API for hex world queries. All cross-feature interaction
goes through HexGrid — downstream features never access `HexTile` internals directly.

**Storage:**

| Field | Type | Description |
|-------|------|-------------|
| `_tiles` | `Dictionary` | `Dictionary[Vector2i, HexTile]` — axial coords to tile |
| `_seed` | `int` | Generation seed for reproducibility |

**Constants:**

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_ELEVATION_DIFF` | `1` | Max elevation difference for traversal |

#### Core API

```gdscript
# Tile queries
func get_tile(coords: Vector2i) -> HexTile
func get_neighbors(coords: Vector2i) -> Array[Vector2i]
func get_tiles_in_range(center: Vector2i, radius: int) -> Array[Vector2i]
func distance(a: Vector2i, b: Vector2i) -> int  # cube/hex distance

# Traversability — MVP rules:
#   biome == WATER → impassable (Bridge deferred)
#   elevation_diff > MAX_ELEVATION_DIFF → impassable (Climbing Gear deferred)
#   structure with blocks_movement: true → impassable (Shelter and Torch are walkable)
func is_passable(from: Vector2i, to: Vector2i) -> bool
func get_elevation_diff(from: Vector2i, to: Vector2i) -> int

# Fog of war — single pass, multiple visibility sources (player + torches).
# See feature-007 for full API documentation.
# sources: Array of { "coords": Vector2i, "radius": int }
# Returns array of newly discovered tiles (were HIDDEN, now VISIBLE).
func refresh_visibility(sources: Array[Dictionary]) -> Array[Vector2i]

# Coordinate conversions
func axial_to_cube(coords: Vector2i) -> Vector3i
func axial_to_world(coords: Vector2i) -> Vector2  # for rendering position
func world_to_axial(world_pos: Vector2) -> Vector2i  # for input hit-testing
```

#### Signals — Cross-Feature Integration API

These are the public contract for downstream features. Subscribe to signals; don't
inspect tile internals.

```gdscript
# World lifecycle
signal map_generated()                     # worldgen complete, safe to query

# Fog of war (both emitted by refresh_visibility() in a single pass)
signal tile_revealed(coords: Vector2i)     # HIDDEN → VISIBLE (first discovery)
signal tile_visibility_changed(coords: Vector2i, state: FogState)  # any fog transition (VISIBLE↔REVEALED)

# Player presence (emitted by movement feature via HexGrid)
signal tile_entered(coords: Vector2i)      # player stepped onto tile
signal tile_exited(coords: Vector2i)       # player left tile

# Resources (emitted by gathering feature via HexGrid)
signal resource_depleted(coords: Vector2i, resource_type: StringName)
signal resource_respawned(coords: Vector2i, resource_type: StringName)

# Structures (emitted by building feature via HexGrid)
signal tile_contents_changed(coords: Vector2i)  # generic catch-all — reserved for future use
signal structure_placed(coords: Vector2i, structure_type: StringName)
signal structure_destroyed(coords: Vector2i, structure_type: StringName)
```

**Ownership pattern:** HexGrid owns the signals and the emit methods. Downstream features
(movement, gathering, building) call HexGrid methods that update tile state and emit the
appropriate signal. This keeps the signal source centralized — no feature emits directly
on HexGrid from outside.

#### Serialization Format

JSON via Godot `FileAccess`. Shape defined here; save/load triggers at dawn via
feature-007 (DayNightCycle). Each feature defines its own save data structure.

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
      "resources": [
        { "type": "wood", "remaining": 3, "max": 3, "tool": "" }
      ]
    }
  ]
}
```

**Serialization convention:** Code uses `q`/`r` (hex grid standard). Serialized JSON uses
`tile_col`/`tile_row` for human readability. Applied across all features that serialize
tile positions.

### Feature Flow

#### World Generation Pipeline

```
SEED (int — random or from save file)
  │
  ├─ Step 1: Place Crash Site
  │     Place tiles at (0,0) and immediate neighbors (radius ~1-2)
  │     Biome = CRASH_SITE, elevation = 0
  │
  ├─ Step 2: Expand map ring-by-ring (BFS from center)
  │     Add tiles outward until count reaches target (200–300, configurable)
  │     Creates a connected, roughly circular map — no islands by construction
  │
  ├─ Step 3: Assign biomes via noise
  │     FastNoiseLite seeded from map seed
  │     Noise value → biome mapping with distance-from-center weighting:
  │       - Inner rings bias toward Grassland
  │       - Mid rings bias toward Forest
  │       - Outer rings bias toward Rocky
  │     Enforces progression curve: Crash Site → Grassland → Forest → Rocky
  │
  ├─ Step 4: Place water tile clusters
  │     ⚠️ IMPLEMENTATION DETAIL — concrete algorithm TBD at implementation time.
  │     Candidate approaches:
  │       (a) Biome boundary placement — detect edges where two biomes meet,
  │           place water clusters at boundary points to create chokepoints
  │       (b) Separate noise layer — second FastNoiseLite with high threshold,
  │           tiles above threshold become WATER; tune threshold to get sparse clusters
  │       (c) Random walk from boundary seeds — pick N boundary points, random-walk
  │           2–4 tiles from each to form organic water shapes
  │     Goal: water clusters sit between biome regions, creating natural chokepoints
  │     that force exploration around them. Not too many (map must be navigable),
  │     not too few (they should matter).
  │
  ├─ Step 5: Post-process biome clusters
  │     Walk all tiles, flood-fill to identify same-biome clusters.
  │     Any cluster > 5 tiles (AC1 constraint): swap edge tiles of the cluster
  │     to an adjacent biome (prefer the neighbor biome with fewest tiles nearby).
  │     This is deterministic and avoids rejection-retry for cluster violations.
  │
  ├─ Step 6: Generate elevation
  │     FastNoiseLite layer (can reuse same noise with different octave/frequency,
  │     or a second noise instance), seeded from map seed.
  │     Raw noise values clamped to biome elevation ranges:
  │       Crash Site → 0, Grassland → 0–1, Forest → 0–2, Rocky → 2–5, Water → 0
  │
  ├─ Step 7: Populate resource nodes
  │     Per-biome resource tables (data-driven, not hardcoded):
  │       Crash Site: Wood (1–2), Stone (1–2), Fiber (1–2) — bare hands, enough
  │                   for first Workbench
  │       Grassland:  Grass, Berries, Fiber — bare hands
  │       Forest:     Wood, Fiber, Berries — bare hands; thick trees → stone_axe
  │       Rocky:      Stone — bare hands; Ore, Crystals → stone_pickaxe
  │       Water:      none
  │     Each tile gets 0–3 resource nodes based on biome density settings.
  │     Resource amounts (remaining/max) randomized within per-type ranges.
  │
  ├─ Step 8: Validate map
  │     ✓ Tile count in 200–300 range
  │     ✓ All required biomes present (GRASSLAND, FOREST, ROCKY, CRASH_SITE)
  │     ✓ Crash Site within 3 hexes of center
  │     ✓ Cluster constraint met (guaranteed by Step 5, but double-check)
  │     ✓ Reachability: A* from Crash Site reaches at least one tile of each
  │       non-WATER biome (elevation + water barriers could isolate a biome)
  │     On failure → re-seed and retry (max 10 attempts).
  │     Retries should be rare — cluster post-processing (Step 5) eliminates the
  │     most common failure mode. Remaining failures are reachability issues from
  │     unlucky elevation/water placement.
  │
  ├─ Step 9: Initialize fog
  │     All tiles → HIDDEN
  │     Crash Site tiles + immediate neighbors → VISIBLE
  │
  └─ Step 10: Emit map_generated()
        Downstream systems (renderer, save, UI) can now safely query HexGrid.
```

#### Design Rationale

**Ring-by-ring expansion over random placement:** Every tile is adjacent to at least one
existing tile by construction. No disconnected islands, no gaps. The map is always
contiguous before biome/elevation assignment.

**Post-processing over rejection-retry for clusters:** Pure noise naturally produces
clusters larger than 5. Rejecting entire maps for cluster violations would burn retries
frequently. Post-processing (swap edge tiles) is deterministic and O(n) — runs once,
always succeeds. Retry is reserved for the harder-to-fix reachability constraint.

**Resource tables are data-driven:** Per-biome resource configuration lives in a
Dictionary or Resource file, not hardcoded in the generation function. This lets
downstream features (gathering, crafting) reference the same tables and makes tuning
easy without code changes.

### Layers & Components

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       └─ HexGridRenderer (Node3D)
            ├─ MultiMeshInstance3D  [biome: CRASH_SITE]
            ├─ MultiMeshInstance3D  [biome: GRASSLAND]
            ├─ MultiMeshInstance3D  [biome: FOREST]
            ├─ MultiMeshInstance3D  [biome: ROCKY]
            └─ MultiMeshInstance3D  [biome: WATER]
```

No FogOverlay node. HIDDEN tiles are not rendered at all — the player sees empty void
(camera background color) where unexplored territory is. REVEALED tiles render dimmed
(reduced material albedo or transparency). VISIBLE tiles render at full brightness.
This is handled per-instance via `MultiMesh.set_instance_custom_data()` — a float flag
per tile that the shader reads to apply the dim/full tint.

#### Autoload

```
HexGrid (Node) — Project Settings → Autoload
```

Pure data + logic. No visuals, no scene tree children. Accessible globally as `HexGrid`.

#### File Structure

```
scripts/
  hex/
    hex_grid.gd           # Autoload — map container, API, signals
    hex_tile.gd           # Resource — tile data
    resource_node.gd      # Resource — gatherable resource on a tile
    hex_math.gd           # Static utility (class_name HexMath) — coords, distance, neighbors
    world_generator.gd    # RefCounted — generation pipeline (Steps 1–10)
    biome_data.gd         # Resource — per-biome config (resources, elevation, weights)

scenes/
  world/
    hex_grid_renderer.gd  # Node3D — manages MultiMesh instances, listens to HexGrid signals
    hex_grid_renderer.tscn # Scene — the 5 MultiMeshInstance3D children

data/
  biomes/
    crash_site.tres       # BiomeData resource — resource tables, elevation 0
    grassland.tres        # BiomeData resource — Grass, Berries, Fiber, elevation 0–1
    forest.tres           # BiomeData resource — Wood, Fiber, Berries, elevation 0–2
    rocky.tres            # BiomeData resource — Stone, Ore, Crystals, elevation 2–5
    water.tres            # BiomeData resource — no resources, elevation 0

shaders/
  hex_tile.gdshader       # Reads instance custom data for fog tint (dim vs full)
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `hex_grid.gd` | Data ownership, public API, signals. Owns `_tiles` Dictionary. | `hex_tile.gd`, `hex_math.gd` |
| `hex_math.gd` | Pure static functions: axial↔cube↔world conversions, distance, neighbors, ring iteration. No state. | Nothing |
| `world_generator.gd` | Runs generation pipeline (Steps 1–10). Creates HexTile instances, hands them to HexGrid, then freed. | `hex_grid.gd`, `hex_math.gd`, `biome_data.gd` |
| `biome_data.gd` | Data-only Resource: resource tables, elevation range, cluster weight, material reference. One `.tres` per biome. | Nothing |
| `hex_grid_renderer.gd` | Manages 5 `MultiMeshInstance3D` nodes (one per biome). Listens to HexGrid signals. Event-driven updates only — no per-frame queries. | `hex_grid.gd` (signals only) |
| `hex_tile.gdshader` | Per-instance fog tinting. Reads custom data float: 0.0 = hidden (not instanced), 0.5 = revealed (dimmed), 1.0 = visible (full). | Nothing (GPU-side) |

#### Rendering Architecture — MultiMesh

Each biome gets one `MultiMeshInstance3D` with a shared hex mesh and biome-specific
material. This gives **~5 draw calls for the entire grid** — well within the <100 budget.

**How it works:**

1. On `map_generated()`, the renderer allocates MultiMesh instances sized to the
   tile count per biome (known after worldgen).
2. Each instance's transform encodes position (from `axial_to_world()`) and
   elevation (Y offset from tile elevation value).
3. Instance visibility is controlled via `MultiMesh.set_instance_custom_data()`:
   - HIDDEN tiles: instance transform set to zero scale (effectively invisible,
     no GPU cost) or instance count managed dynamically.
   - REVEALED/VISIBLE: full scale, custom data float controls shader tint.
4. On `tile_revealed` / `tile_visibility_changed` signals: renderer updates the
   affected instance's custom data and/or transform. Single-instance update, not
   a full rebuild.

**Tile mesh:** Flat-top hexagon, 6 triangles from center, <20 tris. Elevation
creates vertical offset — tiles at elevation 3 sit visually higher than tiles at
elevation 0. No vertical walls between elevation levels for MVP (just the Y offset
communicates height to the player).

**Why not individual tile scenes?** 300 individual `MeshInstance3D` nodes = 300+ draw
calls, already 3x over the mobile budget. MultiMesh batches all same-material tiles
into one draw call. This is a requirement, not an optimization.

#### Architectural Decisions

**HexGrid as autoload, not scene tree node:** Any script in the project can call
`HexGrid.get_tile()` without needing a node reference or `get_node()` path. World
generation, save/load, and UI all access the same singleton. The renderer is the only
component that lives in the scene tree because it needs to be a `Node3D`.

**`hex_math.gd` as static utility (class_name), not autoload:** Pure functions with
zero state don't need singleton lifecycle. `HexMath.distance(a, b)` is cleaner than
adding methods to HexGrid that don't touch map data.

**`world_generator.gd` as RefCounted:** Runs once, produces data, gets garbage
collected. No reason to persist in memory or the scene tree after generation completes.

**BiomeData as `.tres` Resource files:** Tuning biome parameters (resource types,
spawn rates, elevation ranges) is a data change, not a code change. Designers (or
AI agents) can edit `.tres` files without touching GDScript. The renderer reads the
material reference from BiomeData to assign the right material to each MultiMesh.

### Mobile Specs

#### Performance Budget — Hex Grid Share

| Metric | Budget (whole game) | Hex Grid Usage | Remaining |
|--------|-------------------|----------------|-----------|
| Draw calls | <100/frame | ~5 (one MultiMesh per biome) | ~95 for player, structures, resources, UI |
| Memory | <200MB | <1MB (tiles + MultiMesh + mesh + materials) | ~199MB |
| Tris per object | <500 | <20 (hex mesh) | — |

#### World Generation Cost

- 300 tiles × noise sampling + cluster post-processing + A* validation
- Single-threaded GDScript, CPU-bound
- Expected <200ms on mid-range 2022+ devices
- One-time startup cost (not per-frame)
- If >500ms observed: add loading screen (unlikely at this scale)

#### Per-Frame Cost

Zero per-frame work during normal gameplay. Renderer is entirely event-driven:

- `tile_revealed` / `tile_visibility_changed` → single-instance MultiMesh update
  (`set_instance_transform()` + `set_instance_custom_data()`)
- Worst case per move: 6 tiles revealed (all neighbors) = 6 instance updates. Negligible.

#### Touch Input Geometry

- `world_to_axial()`: screen touch → world space → nearest hex center (Red Blob Games
  algorithm, O(1) per touch)
- At 1080×1920 portrait with ~15–20 hex columns visible, each hex is ~54–72px wide
- Exceeds the 48dp minimum touch target requirement

#### Platform Differences

None for this feature. Pure Godot rendering — no native APIs, no network, no
platform-specific code. iOS and Android behave identically.
