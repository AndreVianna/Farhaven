# Building

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Feature identified from REQUIREMENTS.md §5 F6, §9 AC6 | /aid-interview |
| 2026-03-31 | Full technical specification — all sections | /aid-specify |
| 2026-04-02 | Scene tree: ElementIconRenderer → PropRenderer + PropLabelRenderer (feature-003 architecture change). | /spec-update |
| 2026-04-03 | Review fixes: reconciled WALKABLE_STRUCTURES (workbench/storage_chest→walkable, campfire added), structure_destroyed signal acknowledged | /aid-specify review |
| 2026-04-04 | Unified props: structures are props in tile.props[] with category="structure". Multiple structures per hex (footprints must not overlap). Footprint: Array[Vector2i] sub-hex coords. Placement validates sub-hex availability. BuildingSystem shows sub-hex grid during placement. Signals kept, operate on props. | /arch-update |

## Source

- REQUIREMENTS.md §5 F6 (Building)
- REQUIREMENTS.md §9 AC6 (Building acceptance criteria)

## Description

Players place structures on hex tiles via a Build button (always visible in HUD). Building is separate from crafting -- Build places structures, Craft makes tools. Six MVP structures: Workbench, Shelter, Storage Chest, Wall, Torch, Campfire. All indestructible in MVP. Structures use Raw-tier recipes only. Structures are props in `tile.props[]` with `category="structure"` and a footprint defining which sub-hexes they occupy. Multiple structures per hex are allowed as long as footprints don't overlap.

## User Stories

- As a player, I want to build walls and shelter for night safety
- As a player, I want building to feel impactful -- each structure changes the world
- As a player, I want to see where I can place before committing

## Priority

Must (P1 -- Tension)

## Acceptance Criteria

- [ ] Place Workbench on hex with available sub-hexes -> structure prop added, footprint occupied
- [ ] Try to place where footprint overlaps existing prop -> rejected
- [ ] Shelter built -> player inside at night takes 0 damage
- [ ] Wall built -> fauna pathfinding routes around it
- [ ] Structures are indestructible -- fauna cannot damage them

## Save Integration

No separate save data — structures persisted via feature-001 tile data (props with category="structure" in HexTile.props[]).

---

## Technical Specification

### Data Model

#### Structure Definitions — Authoritative Source of Truth

Five MVP structures. This is the canonical reference — other features reference
these definitions but don't own them. **All structures are indestructible in MVP.**

**Map-placed structures:** Structures aren't limited to player-built. MapLoader can
place structures like boulders, ruins, and bridges directly in the map JSON. These
are props with `category="structure"` in `tile.props[]`, same `blocks_movement` rules.
The only difference is origin (MapLoader vs BuildingSystem). See `docs/design/prop-taxonomy.md`.

**Structures are props.** Placed into `tile.props[]` with `category = &"structure"`.
Each structure has a `footprint: Array[Vector2i]` defining which sub-hexes it occupies.

```gdscript
# structure_config: Dictionary[StringName, Dictionary]
{
  &"workbench": {
    "recipe": { &"wood": 5, &"stone": 3 },
    "blocks_movement": false,
    "footprint": [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1)],  # 3 sub-hexes
    "effect": &"crafting_station",
  },
  &"storage_chest": {
    "recipe": { &"wood": 8, &"stone": 4 },
    "blocks_movement": false,
    "footprint": [Vector2i(0,0), Vector2i(1,0)],  # 2 sub-hexes
    "effect": &"expand_inventory",
  },
  &"shelter": {
    "recipe": { &"wood": 10, &"stone": 5, &"fiber": 3 },
    "blocks_movement": false,
    "footprint": [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,1), Vector2i(1,-1)],  # 7 sub-hexes (large)
    "effect": &"respawn_point",
  },
  &"campfire": {
    "recipe": { &"wood": 3, &"fiber": 2 },
    "blocks_movement": false,
    "footprint": [Vector2i(0,0)],  # 1 sub-hex
    "effect": &"cooking_station",
  },
  &"wall": {
    "recipe": { &"wood": 3 },
    "blocks_movement": true,
    "footprint": [Vector2i(0,0), Vector2i(1,0), Vector2i(-1,0)],  # 3 sub-hexes (line)
    "effect": &"none",
  },
  &"torch": {
    "recipe": { &"wood": 2, &"fiber": 1 },
    "blocks_movement": false,
    "footprint": [Vector2i(0,0)],  # 1 sub-hex
    "effect": &"visibility_source",
  },
}
```

**Footprint values are relative to the structure's anchor sub-hex.** When placing,
the anchor is the user-selected sub-hex. Footprint coords are rotated by the
structure's `rotation` before checking availability.

Lives in `data/structure_config.tres` or static Dictionary.

#### Design Rules

- **Multiple structures per hex** — allowed as long as sub-hex footprints don't overlap.
  Structures are props in `tile.props[]` with `category = &"structure"`.
- **All Raw-tier recipes.** No Metal, no Furnace — MVP constraint.
- **`blocks_movement: true`** → queried from `structure_config[prop.type]`. If ANY
  structure prop on the tile has `blocks_movement: true`, `HexGrid.is_passable()`
  returns false for that tile. **Only Wall blocks movement.** All other structures
  (workbench, storage_chest, shelter, campfire, torch) are walkable.
- **Shelter protection:** Player on Shelter tile at night takes 0 fauna contact damage.
  Fauna still approach but deal no damage. (Feature-010 checks this.)
- **Indestructible.** No HP, no damage, no destruction. Walls are permanent.
  Fauna MUST path around. Future work may add durability.
- **Bridge excluded** — deferred. Water impassable in MVP.
- **No runtime HP tracking.** No `_structure_hp` Dictionary.
- **Footprint validation:** A structure can only be placed if all sub-hexes in its
  (rotated) footprint are available — not occupied by any existing prop's footprint
  or sub_hex position.

#### Cross-Feature Structure Effects

| Structure | Effect Feature | Integration |
|-----------|---------------|-------------|
| Workbench | feature-006 (crafting) | `tile.props.any(p.type == &"workbench")` → CraftButton visible |
| Storage Chest | feature-005 (inventory) | `structure_placed(&"storage_chest")` → `Inventory.expand(12)` |
| Shelter | feature-007 (survival) | `structure_placed(&"shelter")` → `_respawn_tile = coords` |
| Shelter | feature-010 (threats) | Player on shelter → 0 fauna contact damage |
| Torch | feature-008 (day/night) | `structure_placed(&"torch")` → `_torch_tiles.append(coords)` |
| Torch | feature-010 (threats) | Torch radius deters fauna spawn |
| Wall | feature-010 (threats) | Blocks fauna movement (routes around via is_passable) |
| All w/ blocks_movement | feature-002 (movement) | AStar2D disconnects edges for tiles with any blocking structure prop |

#### BuildingSystem Properties (on Node)

| Property | Type | Description |
|----------|------|-------------|
| `_is_placing` | `bool` | Placement mode active — gates input at highest priority |
| `_placing_type` | `StringName` | Structure type being placed (`&""` when not placing) |
| `_placing_sub_hex` | `Vector2i` | Selected anchor sub-hex during placement |
| `_placing_rotation` | `float` | Rotation of structure being placed (degrees) |

Structures are written as Prop objects into `tile.props[]`.

#### Signals

```gdscript
signal structure_build_failed(reason: StringName)
    # reasons: &"occupied", &"not_adjacent", &"impassable", &"insufficient_materials"

signal placement_mode_entered(structure_type: StringName)
signal placement_mode_exited()
```

Building success uses HexGrid's centralized signals (operate on props with category="structure"):
- `HexGrid.structure_placed(coords: Vector2i, structure_type: StringName)`
- (No `structure_destroyed` in MVP — structures are indestructible)

#### Save Data

No separate save data. Structures are saved as part of feature-001 tile data
(props with `category="structure"` in `HexTile.props[]`, serialized per-tile in
the hex grid save including `sub_hex` and `footprint`). On load, structure props
are already populated — downstream features (crafting proximity, torch tracking,
shelter respawn, AStar2D edges) react to loaded tile state during initialization,
not via `structure_placed` signals. Feature-001 is the source of truth for
structure persistence.

#### Cross-Feature Dependencies

| This feature queries | Source | What it reads |
|---------------------|--------|---------------|
| `HexGrid.get_tile(coords)` | feature-001 | Tile state for validation |
| `HexGrid.is_passable(from, to)` | feature-001 | Placement validation |
| `Inventory.has_item(type, count)` | feature-005 | Material check |
| `Inventory.remove_item(type, count)` | feature-005 | Material consumption |

| This feature is consumed by | Consumer | What it provides |
|-----------------------------|----------|-----------------|
| feature-002 (movement) | AStar2D edge disconnect on blocking structures |
| feature-005 (inventory) | `structure_placed(&"storage_chest")` → expand(12) |
| feature-006 (crafting) | Workbench proximity check queries `tile.props` for structure props |
| feature-007 (survival) | `structure_placed(&"shelter")` → respawn point |
| feature-008 (day/night) | `structure_placed(&"torch")` → torch tracking |
| feature-010 (threats) | Wall blocks fauna pathing, shelter protects player, torch deters spawn |
| feature-012 (HUD) | `structure_build_failed` → floating text feedback |

---

### Feature Flow

#### Build Flow

```
Player taps Build button (HUD, always visible)
  │
  ├─ Build panel opens (bottom drawer, mutual exclusion with all other panels)
  │     Shows 5 structures with recipes + affordability
  │     Affordable = bright + active BUILD button
  │     Unaffordable = dimmed + greyed button
  │
  ├─ Player taps BUILD on a structure entry (e.g., Wall)
  │
  ├─ Enter placement mode:
  │     _is_placing = true
  │     _placing_type = &"wall"
  │     Close Build panel (world needs to be visible for tile selection)
  │     Emit placement_mode_entered(&"wall")
  │     Call HexGridRenderer.highlight_tiles(valid_tiles, Color.CYAN)
  │       where valid_tiles = adjacent tiles that pass validation:
  │         - HexGrid.get_neighbors(player.current_tile)
  │         - Tile is passable (not water, not cliff)
  │         - Tile has enough free sub-hexes for the structure's footprint
  │     Show sub-hex grid overlay on highlighted tiles for precise placement
  │     Show placement label: "TAP TO PLACE WALL"
  │
  ├─ Player taps a highlighted tile (selects anchor sub-hex):
  │     The tap position determines the anchor sub-hex within the tile.
  │     Footprint is computed relative to anchor, rotated by _placing_rotation.
  │
  │   ├─ Validate (defensive — highlights already filter, but verify):
  │   │     ✗ Not adjacent to player → reject
  │   │     ✗ Footprint overlaps existing prop sub-hexes → structure_build_failed(&"occupied")
  │   │     ✗ Footprint extends outside the 19 sub-hex grid → structure_build_failed(&"occupied")
  │   │     ✗ Water or cliff → structure_build_failed(&"impassable")
  │   │     ✗ Insufficient materials →
  │   │         structure_build_failed(&"insufficient_materials")
  │   │
  │   ├─ Consume materials:
  │   │     For each (material, count) in structure.recipe:
  │   │       Inventory.remove_item(material, count)
  │   │
  │   ├─ Place structure as prop:
  │   │     var prop = Prop.new()
  │   │     prop.type = _placing_type
  │   │     prop.sub_hex = _placing_sub_hex  # anchor sub-hex
  │   │     prop.category = &"structure"
  │   │     prop.footprint = rotated_footprint  # all occupied sub-hexes
  │   │     prop.rotation = _placing_rotation
  │   │     HexGrid.get_tile(coords).props.append(prop)
  │   │     Emit HexGrid.structure_placed(coords, _placing_type)
  │   │
  │   ├─ Downstream reactions (via structure_placed signal):
  │   │     &"storage_chest" → Inventory.expand(12)              (feature-005)
  │   │     &"shelter"       → SurvivalSystem._respawn_tile      (feature-007)
  │   │     &"torch"         → DayNightCycle._torch_tiles        (feature-008)
  │   │     &"workbench"     → CraftingSystem proximity re-check (feature-006)
  │   │     if blocks_movement → AStar2D disconnect edges         (feature-002)
  │   │
  │   └─ Exit placement mode
  │
  ├─ Player taps non-highlighted area or Build button → CANCEL:
  │     No materials consumed
  │     HexGridRenderer.clear_highlights()
  │     Hide placement label
  │     Exit placement mode
  │
  └─ Exit placement mode:
       _is_placing = false
       _placing_type = &""
       HexGridRenderer.clear_highlights()
       Emit placement_mode_exited()
```

#### Input Priority During Placement Mode

When `_is_placing == true`, BuildingSystem has the **lowest `process_priority` value**
(runs first in `_unhandled_input`). It claims ALL taps:

- Tap on highlighted tile → place structure
- Tap on non-highlighted area → cancel
- Tap on Build button → cancel

Calls `get_viewport().set_input_as_handled()` on every tap. No fall-through to
scanner/auto-interaction/movement.

When `_is_placing == false`, BuildingSystem passes through — does not call
`set_input_as_handled()`. Normal input priority resumes.

#### Highlight Recalculation on Player Movement

If the player moves during placement mode (via joystick — taps are consumed by
placement), the valid tiles change. On `tile_entered` while `_is_placing`:

```
1. HexGridRenderer.clear_highlights()
2. Recompute valid tiles from new player position
3. HexGridRenderer.highlight_tiles(new_valid_tiles, Color.CYAN)
```

This keeps highlights accurate as the player walks with joystick during placement.

---

### Layers & Components

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       ├─ WorldEnvironment                      [feature-008]
       ├─ DirectionalLight3D                    [feature-008]
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ PropRenderer (Node3D)                  [feature-003]
       ├─ PropLabelRenderer (Node3D)              [feature-003]
       ├─ ScanProgressRenderer (Node3D)         [feature-003]
       ├─ PropRenderer (Node3D)             [feature-004]
       ├─ StructureRenderer (Node3D)            ← THIS FEATURE
       │    ├─ MultiMeshInstance3D [workbench]
       │    ├─ MultiMeshInstance3D [storage_chest]
       │    ├─ MultiMeshInstance3D [shelter]
       │    ├─ MultiMeshInstance3D [campfire]
       │    ├─ MultiMeshInstance3D [wall]
       │    └─ MultiMeshInstance3D [torch]
       ├─ GroundItemRenderer (Node3D)           [feature-007]
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)               [feature-002]
       │    ├─ ScannerSystem (Node)             [feature-003]
       │    ├─ AutoInteractionSystem (Node)     [feature-004]
       │    ├─ CraftingSystem (Node)            [feature-006]
       │    ├─ SurvivalSystem (Node)            [feature-007]
       │    └─ BuildingSystem (Node)            ← THIS FEATURE
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ HUD (CanvasLayer)                          [feature-012]
       ├─ BuildButton (TextureButton)           ← THIS FEATURE (always visible, 64×64px)
       ├─ (other HUD elements)
       └─ BuildPanel (PanelContainer)           ← THIS FEATURE (bottom drawer)
            └─ ScrollContainer
                 └─ StructureList (VBoxContainer)
  └─ ScreenFade (CanvasLayer)                   [feature-007]
```

#### File Structure

```
scripts/
  building/
    building_system.gd       # Node (child of Player) — placement validation,
                              #   build action, placement mode, input priority
    structure_renderer.gd    # Node3D — MultiMesh per structure type

scenes/
  world/
    structure_renderer.tscn  # 6 MultiMeshInstance3D children

ui/
  build_panel.gd             # Control — structure list, BUILD button per entry
  structure_entry_ui.gd      # Control — single structure row (name, recipe, button)

data/
  structure_config.tres      # Resource — structure definitions
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `building_system.gd` | Child Node of Player. `_is_placing` flag. Placement validation (adjacent, passable, sub-hex footprint available, materials). Material consumption via Inventory. Creates Prop with `category="structure"`, appends to `tile.props[]`, emits `HexGrid.structure_placed`. Shows sub-hex grid overlay during placement. Input priority: lowest `process_priority` when `_is_placing`. Calls `HexGridRenderer.highlight_tiles`/`clear_highlights`. Highlight recalc on player movement during placement. | `HexGrid` (tile queries, structure_placed signal), `HexGridRenderer` (highlight API, sub-hex overlay), `Inventory` feature-005 (has_item, remove_item) |
| `structure_renderer.gd` | Node3D under World. One MultiMeshInstance3D per structure type (~6 draw calls). Adds instance at prop's sub-hex world position on `structure_placed`. Fog-aware visibility (hidden if tile HIDDEN). Placeholder meshes (colored boxes/shapes). | `HexGrid` (structure_placed signal, tile fog) |
| `build_panel.gd` | Control on BuildPanel. Shows 5 structures with recipe costs and affordability. BUILD tap triggers `building_system.enter_placement_mode(type)`. `panel_opened` signal for mutual exclusion. Refreshes on `inventory_changed`. | `BuildingSystem`, `Inventory` feature-005 (get_count for affordability) |
| `structure_entry_ui.gd` | Single structure row. Icon + name + ingredients (owned/needed, green/red) + BUILD button (active or greyed). | `Inventory`, `structure_config` |

#### Signal Wiring — Complete

```
building_system.gd                       HexGrid
  (build action)                     ──►  structure_placed(coords, type)

building_system.gd                       HexGridRenderer (feature-001)
  placement_mode_entered             ──►  highlight_tiles(valid_tiles, CYAN)
  placement_mode_exited              ──►  clear_highlights()
  (on tile_entered while placing)    ──►  recalc highlights

HexGrid signals                          structure_renderer.gd
  structure_placed(coords, type)     ──►  add structure MultiMesh instance

HexGrid signals                          building_system.gd
  tile_entered(coords)               ──►  recalc highlights if _is_placing

Inventory (feature-005) signals          build_panel.gd
  inventory_changed()                ──►  refresh affordability display

building_system.gd                       feature-012 (HUD)
  structure_build_failed(reason)     ──►  floating error text
  placement_mode_entered(type)       ──►  show "TAP TO PLACE [TYPE]" label
  placement_mode_exited()            ──►  hide placement label
```

#### Tile Highlight API (on HexGridRenderer, feature-001)

```gdscript
func highlight_tiles(coords: Array[Vector2i], color: Color) -> void
func clear_highlights() -> void
```

Uses per-instance custom data highlight channel in the hex shader. Zero additional
draw calls — same MultiMesh instances, different custom data value.

#### Panel Mutual Exclusion

5-panel list:
1. Inventory (feature-005)
2. Crafting (feature-006)
3. **Build (this feature)**
4. Catalog (feature-003)
5. Journal (feature-011)

Symmetric `panel_opened` signal pattern.

#### Build Panel — Open/Close

- **Open:** Tap BuildButton (HUD, always visible, 64×64px) → drawer slides up.
  Game continues running — no pause. ~55% screen visible above.
- **Close:** BuildButton again, X button, or tap game area above.
- Refreshes on `inventory_changed` (materials may have changed).

### UI Specs

#### Build Panel Layout — Portrait 1080×1920

```
┌──────────────────────────┐
│      (game world visible)│  ← ~55%
│                          │
├──────────────────────────┤
│  BUILD               [X] │
│ ─────────────────────────│
│ ┌──────────────────────┐ │
│ │ Workbench            │ │
│ │  Wood: 3/5  Stone: 2/3 │ │
│ │                [BUILD]│ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ Wall                 │ │
│ │  Wood: 5/3     [BUILD]│ │  ← affordable
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ Shelter              │ │
│ │  Wood: 3/10 ...  [--]│ │  ← greyed
│ └──────────────────────┘ │  ← ~45% height, scrollable
└──────────────────────────┘
```

#### Structure Entry States

| State | Visual | Build Button |
|-------|--------|-------------|
| Affordable | Full brightness, ingredients green | Active — enters placement mode |
| Unaffordable | Dimmed, short ingredients red | Greyed — not tappable |

No "already owned" state — structures can be placed multiple times (walls, torches).

#### Placement Mode Overlay

When BUILD is tapped:
- Panel closes
- Valid adjacent tiles highlighted cyan
- Sub-hex grid overlay shown on highlighted tiles (19 sub-hex outlines per tile)
- Structure footprint preview follows tap position, snapping to sub-hex anchors
- Available sub-hexes shown in green, occupied in red
- Floating label: "TAP TO PLACE WALL" (or structure name)
  - Design system TBD (MVP: clean sans-serif, uppercase, semi-transparent)
- Tap valid sub-hex → place, highlights clear, sub-hex overlay clears, label disappears
- Tap elsewhere → cancel, highlights clear, sub-hex overlay clears, label disappears

#### Touch Targets

- Structure entry: ~100px height
- BUILD button per entry: ~80×48px
- BuildButton (HUD): 64×64px
- Close (X): 48×48px
- Placement: hex tiles (~54-72px, above 48dp)

#### Panel Consistency

Same bottom-drawer pattern as all panels (full width, ~45% height, semi-transparent,
scroll, game continues, mutual exclusion with 4 other panels).

---

### Mobile Specs

#### Performance

| Operation | Cost | When |
|-----------|------|------|
| Placement validation | O(6): check 6 neighbors for passability + structure | On placement mode enter + tile_entered during placing |
| Material check | O(i): i = ingredients per structure (2-3) | On BUILD tap |
| Material consume | O(i): remove per ingredient | On placement confirm |
| Highlight update | O(6): update custom data for 6 tiles | On placement enter/move |

All O(n) with n ≤ 6. Negligible.

#### Draw Calls

| Renderer | Draw Calls | Notes |
|----------|-----------|-------|
| StructureRenderer | ~6 | One MultiMesh per structure type |
| Highlight overlay | 0 | Uses existing hex tile custom data channel |
| Sub-hex overlay | 0 | Rendered into same ArrayMesh or temporary overlay mesh during placement |
| BuildPanel (UI) | 0 | CanvasLayer |
| **Total** | **~6** | Running total: terrain ~5, icons ~6, resources ~6, ground ~1, structures ~6 = ~24 |

#### Touch Interaction

- BuildButton (HUD): 64×64px, always visible
- Structure entries: ~100px rows
- Placement mode: tap targets are hex tiles (~54-72px)
- All standard `_gui_input` / `_unhandled_input`

#### Platform Differences

None. Godot UI + HexGrid queries. iOS/Android identical.

#### Memory

- structure_config: 6 entries = negligible
- StructureRenderer: 6 MultiMesh pools × ~20 instances max = <10KB
- BuildingSystem state: 4 properties = negligible
