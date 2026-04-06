# Sub-Hex Grid + Unified Props — Architecture Decision & Impact Report

**Date:** 2026-04-04
**Decision by:** Andre + Lola
**Status:** Approved

---

## Architecture Decision

### 1. Sub-Hex Grid

Each main hex (6m diameter) is divided into 19 sub-hexes (1.2m diameter) using axial coordinates (sq, sr). Same coordinate system as the main grid, smaller scale.

```
Ring 0 (center):  (0,0)
Ring 1 (inner 6): (-1,0) (0,-1) (1,-1) (1,0) (0,1) (-1,1)
Ring 2 (outer 12): (-2,0) (-1,-1) (0,-2) (1,-2) (2,-2) (2,-1)
                   (2,0) (1,1) (0,2) (-1,2) (-2,2) (-2,1)
```

**Full address of anything in the world:** (q, r, sq, sr) — main hex + sub-hex position.

**Scale:** SUB_HEX_SIZE = HEX_SIZE / 5 = 0.6 (radius). Diameter = 1.2m.

**World position:** `world_pos = hex_center(q, r) + axial_to_pixel(sq, sr) * sub_scale`

### 2. Unified Props List

**The old model (REMOVED):**
```
tile.resources = [ResourceNode, ...]
tile.structure = StringName       # one per hex
tile.anomaly = StringName         # one per hex
```

**The new model:**
```
tile.props = [
  {type: "wood",            sub_hex: Vector2i(1, 0),  category: Category.RESOURCE},
  {type: "workbench",       sub_hex: Vector2i(0, 0),  category: Category.STRUCTURE, footprint: [Vector2i(0,0), Vector2i(1,0)]},
  {type: "torch",           sub_hex: Vector2i(-1, 1), category: Category.STRUCTURE, footprint: [Vector2i(-1,1)]},
  {type: "anomaly_ch1_001", sub_hex: Vector2i(0, -1), category: Category.ANOMALY},
]
```

**Principle:** The hex doesn't know what things ARE — it knows what things are IN it and WHERE they sit. The type's registry entry (ResourceDef, StructureDef, etc.) defines behavior. The hex is just a container of positioned props.

### 3. Gameplay Boundaries

| System | Unit | Changes? |
|--------|------|----------|
| Movement (smooth) | Continuous world space | NO |
| Fog of war | Main hex | NO |
| Biome | Main hex | NO |
| Elevation | Main hex | NO |
| Pathfinding/traversal | Main hex | NO |
| Prop placement | **Sub-hex** | YES — new |
| Resource gathering | Proximity (world space) | MINOR — distance calc updated |
| Structure interaction | Proximity (world space) | MINOR — distance calc updated |
| Scanning/Catalog | Main hex | NO |
| Save/Load | Additive fields | MINOR |

---

## Impact by System

### HIGH Impact

#### HexTile Data Model
- **Remove:** `resource_nodes: Array[ResourceNode]`, `structure: StringName`, `anomaly: StringName`
- **Add:** `props: Array[Prop]`
- **Prop structure:** `{type: StringName, sub_hex: Vector2i, category: int (Prop.Category enum), footprint: Array[Vector2i], rotation_deg: float, remaining: int, max_amount: int, ...}`
- **Category values:** `Category.RESOURCE = 0`, `Category.STRUCTURE = 1`, `Category.ANOMALY = 2` (int enum, extensible)
- **Dependencies:** Everything that reads tile data

#### MapLoader
- **Map JSON format change:**
  ```json
  "0,0": {
    "biome": "crash_site",
    "elevation": 0,
    "props": [
      {"type": "wood", "sub_hex_q": 1, "sub_hex_r": 0, "category": 0, "rotation": 18},
      {"type": "workbench", "sub_hex_q": 0, "sub_hex_r": 0, "category": 1, "blocks_movement": true}
    ]
  }
  ```
  Note: `remaining`/`max_amount` are optional for resource props — defaults from biome data.
- **Backward compat:** Old format with `resources[]` + `structure` + `anomaly` → auto-convert to `props[]` on load. Resources without sq/sr → convert offset to nearest sub-hex.
- **Validation:** Check sub-hex range, footprint overlap, spawn uniqueness

#### ResourceRenderer → PropRenderer (rename)
- Unified renderer for all prop categories (or category-specific sub-renderers sharing base)
- Two-level positioning: hex center + sub-hex offset + micro offset
- Category determines mesh source (ResourceDef vs StructureDef vs marker)
- Footprint rendering for multi-sub-hex structures

### MEDIUM Impact

#### HexMath
- **Add constant:** `SUB_HEX_SIZE = HEX_SIZE / 5.0` (0.6)
- **Add functions:**
  - `sub_axial_to_world(sub_coords: Vector2i) -> Vector2` — sub-hex relative to hex center
  - `world_to_sub_axial(offset_from_center: Vector2) -> Vector2i` — click detection
  - `get_sub_hex_neighbors(sub_coords: Vector2i) -> Array[Vector2i]`
  - `is_valid_sub_hex(sub_coords: Vector2i) -> bool` — within radius 2
  - `get_all_sub_hexes() -> Array[Vector2i]` — all 19 positions
- **No changes to existing functions** — purely additive

#### HexGrid
- **Add APIs:**
  - `get_props_at(coords: Vector2i) -> Array[Prop]` — all props in a tile
  - `get_props_at_sub_hex(coords: Vector2i, sub_hex: Vector2i) -> Array[Prop]`
  - `get_props_by_category(coords: Vector2i, category: StringName) -> Array[Prop]`
  - `is_sub_hex_occupied(coords: Vector2i, sub_hex: Vector2i) -> bool`
  - `add_prop(coords: Vector2i, prop: Prop) -> void`
  - `remove_prop(coords: Vector2i, prop: Prop) -> void`
- **Signals update:** `structure_placed` / `structure_destroyed` → generalize to `prop_placed` / `prop_removed` (or keep both for backward compat during transition)
- **Traversal:** WALKABLE_STRUCTURES logic checks props by category instead of single structure field

#### AutoInteractionSystem
- **Gather proximity:** Distance calculation uses sub-hex world position instead of hex center + offset
- **Respawn queue:** Track (coords, sub_hex) instead of just coords
- **Resource lookup:** `tile.props.filter(category == "resource")` instead of `tile.resource_nodes`

#### SurvivalSystem (ground items)
- **Ground items stay main-hex** for MVP (death drops don't use sub-hex)
- `_ground_items` data structure unchanged
- Future: could place dropped items at specific sub-hexes

### LOW Impact

#### DayNightCycle
- Torch tracking: currently listens for `structure_placed` with type `"torch"`
- Update to: listen for `prop_placed` with category `"structure"` and type `"torch"`
- Or: filter props list for torches. Minimal change.

#### SaveManager
- No changes — passes through HexGrid.get_save_data()

#### HexGrid Serialization
- `get_save_data()` serializes `props[]` instead of separate resource/structure/anomaly fields
- `load_save_data()` deserializes with backward compat (old saves → convert to props)

#### Existing Tests
- Tests referencing `tile.resource_nodes`, `tile.structure`, `tile.anomaly` need updating
- Test helper mocks need props-based API
- **Estimated:** ~50-80 test modifications across all suites

### NO Impact

- Player movement (smooth, world-space)
- Camera system
- Fog of war / visibility
- Biome system
- Elevation system
- Pathfinding / traversal (operates on main hex, checks prop occupancy differently but same logic)
- ScreenFade, StatBars, DayCounter UI

---

## Data Migration

### ch1.json (61 tiles)
Old → New conversion needed. Write a one-time migration script:
1. `resources[]` entries → `props[]` with `category: "resource"`, convert offset to (sq, sr)
2. `structure` field → prop entry with `category: "structure"`, footprint at center (0,0)
3. `anomaly` field → prop entry with `category: "anomaly"` at center (0,0)
4. `spawn: true` → prop entry with `category: "spawn"` at center (0,0)

### Existing saves
Backward compat in `load_save_data()`:
- Detect old format (has `resources` key but no `props` key) → convert on load
- New saves use `props[]` format

---

## Implementation Order

### Phase 1: Data Model (foundation)
1. HexMath sub-hex functions + tests
2. Prop data structure definition
3. HexTile refactor: props[] replaces resources/structure/anomaly

### Phase 2: Map Loading
4. MapLoader: new format + backward compat
5. ch1.json migration
6. Map validation

### Phase 3: Rendering
7. PropRenderer (replaces ResourceRenderer + StructureRenderer concept)
8. Visual smoke test

### Phase 4: Gameplay Wiring
9. AutoInteractionSystem: use props API
10. DayNightCycle: torch tracking via props
11. HexGrid signals: prop_placed/prop_removed
12. Traversal: check props for walkability

### Phase 5: Persistence
13. HexGrid serialization: props format
14. Save/load backward compat
15. Integration tests

### Phase 6: Test Migration
16. Update all existing tests to props-based API

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Breaking existing 918 tests | HIGH | HIGH | Phase 6 dedicated to test migration; run suite after each phase |
| ch1.json migration errors | MEDIUM | MEDIUM | Write migration script with validation; keep old format backup |
| Renderer positioning bugs | MEDIUM | MEDIUM | Visual smoke test at Phase 3; compare with current rendering |
| Scope creep (sub-hex scanning, fauna, etc.) | HIGH | MEDIUM | Strict MVP scope: props placement only |
| Performance (19x more potential objects per hex) | LOW | LOW | Most hexes have 1-3 props; MultiMesh handles it |

---

*This document supersedes the separate resource/structure/anomaly model from delivery-001 through delivery-004.*
