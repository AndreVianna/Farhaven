# Building & Night Threats

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F6/F9, §9 AC6/AC9 | /aid-interview |
| 2026-03-31 | Data Model written — indestructible structures, combat, meat drops | /aid-specify |
| 2026-03-31 | Feature Flow written — build, fauna lifecycle, combat, meat via signal | /aid-specify |
| 2026-03-31 | Layers & Components written — tile highlight API, placement input priority | /aid-specify |
| 2026-03-31 | UI Specs written — build panel, combat feedback, Tactical Brutalism labels | /aid-specify |
| 2026-03-31 | Audit fixes applied (see delivery DETAIL.md) | /audit |

## Source

- REQUIREMENTS.md §5 F6 (Building)
- REQUIREMENTS.md §5 F9 (Night Threats)
- REQUIREMENTS.md §9 AC6 (Building acceptance criteria)
- REQUIREMENTS.md §9 AC9 (Night Threats acceptance criteria)
- REQUIREMENTS.md §10 P1 — Tension

## Description

Players place structures on hex tiles (one per tile). Structures block movement, which is critical for night defense — walls redirect fauna, Shelter provides a safe zone where the player takes zero damage at night. Structures have HP and can be damaged by fauna.

Starting Day 4, simple fauna spawn at night outside lit and walled areas. They move toward the player when within 2 hexes and deal damage on contact. All fauna despawn at dawn. Days 1–3 are peaceful (onboarding). The player can fight back with tools (slow, costly) or shelter (smart play). Night is a pressure/timer mechanic, not a combat game.

Building and threats are combined because they form a single gameplay unit: you build to defend, threats make building meaningful.

## User Stories

- As a player, I want to build walls and shelter so I feel safe at night
- As a player, I want night threats to create tension so the day/night cycle has stakes
- As a player, I want the first few days to be peaceful so I can learn without dying

## Priority

Must (P1 — Tension)

## Acceptance Criteria

- [ ] Place Workbench on empty hex → occupied, blocks movement
- [ ] Try to place on occupied hex → rejected
- [ ] Shelter built → player inside at night takes 0 damage
- [ ] Wall built → fauna pathfinding routes around it
- [ ] Fauna attacks unprotected structure → HP decreases
- [ ] Day 3 night → zero fauna spawn
- [ ] Day 4 night → 1–3 fauna spawn outside lit/walled area
- [ ] Fauna within 2 hexes → moves toward player
- [ ] Fauna contacts player → defined HP damage
- [ ] Dawn → all fauna despawn

## Save Integration

Adds placed structures (type, position, HP) and fauna state to save data.

---

## Technical Specification

### Data Model

#### Structure Definitions — Authoritative Source of Truth

Five MVP structures. This is the canonical reference — other features reference these
definitions but don't own them. **All structures are indestructible in MVP.** No HP,
no damage, no repair. Fauna cannot destroy structures.

```gdscript
# structure_config: Dictionary[StringName, Dictionary]
{
  &"workbench": {
    "recipe": { &"wood": 5, &"stone": 3 },
    "blocks_movement": true,
    "effect": &"crafting_station",    # enables Craft button proximity (feature-005)
  },
  &"storage_chest": {
    "recipe": { &"wood": 8, &"stone": 4 },
    "blocks_movement": true,
    "effect": &"expand_inventory",    # +12 inventory slots (feature-004)
  },
  &"shelter": {
    "recipe": { &"wood": 10, &"stone": 5, &"fiber": 3 },
    "blocks_movement": false,         # player stands ON shelter for protection
    "effect": &"respawn_point",       # updates _respawn_tile (feature-006)
                                       # player on shelter tile at night = 0 fauna damage
  },
  &"wall": {
    "recipe": { &"wood": 3 },
    "blocks_movement": true,
    "effect": &"none",                # pure pathing blocker — fauna must route around
  },
  &"torch": {
    "recipe": { &"wood": 2, &"fiber": 1 },
    "blocks_movement": false,         # walkable
    "effect": &"visibility_source",   # night visibility radius 2 (feature-007)
                                       # deters fauna spawn in radius (this feature)
  },
}
```

**Key design rules:**
- One structure per tile (feature-001: `HexTile.structure: StringName`).
- All recipes use Raw-tier materials only (no Metal — MVP constraint).
- `blocks_movement: true` → `HexGrid.is_passable()` returns false. Shelter and Torch
  are walkable — player can stand on them.
- **Shelter protection:** Player on a Shelter tile at night takes 0 fauna contact damage.
  Fauna still move toward the player but deal no damage while player is on Shelter.
- **Indestructible (MVP).** No HP, no structure_destroyed from fauna. Walls are
  permanent once placed. This makes walls strategically reliable — fauna MUST path around.
- Bridge excluded — deferred. Water is impassable in MVP.

**No runtime HP tracking needed.** No `_structure_hp` Dictionary. Structures are
placed and persist until... they just persist. Future work may add durability.

#### Cross-Feature Structure Effects

| Structure | Feature | Integration |
|-----------|---------|-------------|
| Workbench | feature-005 | `tile.structure == &"workbench"` → CraftButton visible |
| Storage Chest | feature-004 | `structure_placed(&"storage_chest")` → `Inventory.expand(12)` |
| Shelter | feature-006 | `structure_placed(&"shelter")` → `_respawn_tile = coords` |
| Torch | feature-007 | `structure_placed(&"torch")` → `_torch_tiles.append(coords)` |
| Wall | — | No cross-feature effect. Blocks movement only. |

#### Fauna Entity — Transient

Fauna are lightweight Dictionaries in an array — not Nodes, not Resources. 1-3 per
night, processed in `_process` by FaunaManager.

```gdscript
# Each fauna instance:
{
  "id": int,                  # unique per spawn cycle
  "coords": Vector2i,         # current tile
  "hp": int,                  # takes damage from player attacks
  "move_cooldown": float,     # seconds between tile moves
  "cooldown_remaining": float, # timer
}
```

#### Fauna Config

```gdscript
const FAUNA_CONFIG: Dictionary = {
    "hp": 20,
    "contact_damage": 10,         # HP to player per move cycle when adjacent
    "move_cooldown": 1.0,         # seconds between tile moves
    "detection_range": 2,         # hexes — move toward player if within range
    "spawn_count_min": 1,
    "spawn_count_max": 3,
    "first_spawn_day": 4,         # Days 1-3 peaceful (onboarding)
    "meat_drop_amount": 1,        # meat dropped on kill
}
```

#### Combat — Player Attacks Fauna

**Attack trigger:** Tap adjacent fauna tile = attack. Same input pattern as gathering
(tap adjacent = interact). Attack priority: fauna on tile > resource on tile > movement.

**Weapon damage:**

| Equipped Weapon | Damage | Hits to Kill (20 HP) |
|----------------|--------|---------------------|
| Survival Knife (starter) | 10 | 2 hits |
| Bare hands (no weapon) | 5 | 4 hits |

Attack cooldown: 1.0s between hits (same rhythm as gathering).

**Combat feedback:** Damage number floats from fauna (same pattern as gather "+1 Wood").
No attack animation for MVP — just the number.

**Tool lookup:** `Inventory.get_tool(&"weapon")` → determines damage. Same auto-use
pattern as gathering tools. No manual equip.

```gdscript
const WEAPON_DAMAGE: Dictionary = {
    &"survival_knife": 10,
    &"": 5,  # bare hands
}
```

#### Fauna Drops — Meat

On kill, fauna drops `&"meat"` on the death tile as a ground item (same system as
feature-006 death drops). Auto-pickup on `tile_entered`.

**New resource type addition:**

Add to feature-004 item_config:
```gdscript
&"meat": { "max_stack": 20, "category": &"consumable" },
```

Add to feature-006 CONSUMABLE_CONFIG:
```gdscript
&"meat": { "hunger": 25.0, "thirst": 0.0 },
```

Meat is the best hunger item (25 vs berries' 15). Only source: fauna kills. Night
becomes dual-purpose: danger AND opportunity.

#### Spawn Rules

Fauna spawn at NIGHT start (`DayNightCycle.night` signal). Only if
`DayNightCycle.day_count >= FAUNA_CONFIG.first_spawn_day`.

Spawn tiles must be:
- `fog_state != VISIBLE` (outside player sight and torch range)
- No structure on tile (`structure == &""`)
- Passable (not water, not cliff)
- At least 3 hexes from player (don't spawn adjacent)

Spawn count: `randi_range(spawn_count_min, spawn_count_max)`.

#### Signals

```gdscript
# Building
signal structure_build_failed(reason: StringName)

# Fauna
signal fauna_spawned(id: int, coords: Vector2i)
signal fauna_moved(id: int, from: Vector2i, to: Vector2i)
signal fauna_attacked_player(id: int, damage: int)
signal fauna_killed(id: int, coords: Vector2i)
signal fauna_despawned(id: int)
```

Building success uses existing HexGrid signals (`structure_placed`, `structure_destroyed`).
No `fauna_attacked_structure` — structures are indestructible in MVP.

#### Save Data

```json
{
  "structures": [
    { "tile_col": 2, "tile_row": -1, "type": "workbench" },
    { "tile_col": 3, "tile_row": 0, "type": "shelter" },
    { "tile_col": 4, "tile_row": 0, "type": "wall" }
  ]
}
```

Structure positions use tile_col/tile_row convention matching all other save sections.
No HP (indestructible). Fauna are NOT saved — transient per-night. On load during
NIGHT phase, re-run spawn logic.

### Feature Flow

#### Build Flow

```
Player taps Build button (HUD, always visible)
  │
  ├─ Build panel opens (bottom drawer, mutual exclusion with Inventory/Crafting)
  │     Shows 5 structures with recipes + affordability
  │     Same pattern as Crafting panel: affordable = bright, unaffordable = greyed
  │
  ├─ Player taps a structure (e.g., Wall)
  │
  ├─ Enter placement mode:
  │     Close Build panel to show the world
  │     Highlight adjacent tiles that are valid placement targets:
  │       passable, no structure, not water/cliff, within 1 hex of player
  │
  ├─ Player taps a highlighted tile
  │
  ├─ Validate:
  │     ✗ Not adjacent → reject
  │     ✗ Has structure → reject (one per tile)
  │     ✗ Water/cliff → reject
  │     ✗ Insufficient materials → structure_build_failed(&"insufficient_materials")
  │
  ├─ Consume materials:
  │     For each (material, count) in structure.recipe:
  │       Inventory.remove_item(material, count)
  │
  ├─ Place structure:
  │     HexGrid.get_tile(coords).structure = structure_type
  │     Emit HexGrid.structure_placed(coords, structure_type)
  │
  ├─ Downstream reactions (via structure_placed signal):
  │     &"storage_chest" → Inventory.expand(12)                  (feature-004)
  │     &"shelter"       → SurvivalSystem._respawn_tile update   (feature-006)
  │     &"torch"         → DayNightCycle._torch_tiles append     (feature-007)
  │     &"workbench"     → CraftingSystem proximity re-check     (feature-005)
  │     if blocks_movement → AStar2D disconnect tile edges        (feature-002)
  │
  ├─ Exit placement mode
  └─ Done
```

**Placement cancel:** Tap non-highlighted area or Build button → exit placement mode,
no materials consumed. Clears highlights via `HexGridRenderer.clear_highlights()`.

**Input during placement mode:** `BuildingSystem.is_placing == true` → BuildingSystem
intercepts `_unhandled_input` at highest priority (lowest `process_priority` value),
before fauna/gather/movement checks. All taps route to placement logic. Cancel
restores normal input priority.

#### Fauna Lifecycle

**Spawn (night signal):**

```
DayNightCycle emits night()
  │
  ├─ if day_count < FAUNA_CONFIG.first_spawn_day: return (Days 1-3 peaceful)
  │
  ├─ count = randi_range(spawn_count_min, spawn_count_max)
  │
  ├─ For each spawn:
  │     Find valid tile:
  │       fog_state != VISIBLE
  │       structure == &""
  │       passable (not water/cliff)
  │       distance from player >= 3 hexes
  │     Create fauna entry in _fauna
  │     Emit fauna_spawned(id, coords)
  │
  └─ Done
```

**Movement tick (_process, NIGHT only):**

```
For each fauna in _fauna:
  │
  ├─ cooldown_remaining -= delta
  ├─ if cooldown_remaining > 0: continue
  ├─ Reset cooldown_remaining = move_cooldown
  │
  ├─ Player within detection_range (2 hexes)?
  │     ✗ No → idle (don't move)
  │     ✓ Yes → move one tile toward player
  │
  ├─ Pick move target:
  │     From neighbors, pick closest to player (hex distance)
  │     Must be passable (walls block — fauna routes around)
  │     Must not have another fauna (no stacking)
  │     ✗ No valid move → stay put
  │
  ├─ Move fauna:
  │     fauna.coords = new_tile
  │     Emit fauna_moved(id, from, to)
  │
  ├─ Contact damage check — is fauna now adjacent to player?
  │     Player on Shelter tile? → 0 damage (shelter protection)
  │     Else → player takes contact_damage (10 HP)
  │     Emit fauna_attacked_player(id, damage_dealt)
  │
  └─ End
```

**Contact damage is fauna-move-only (intentional design decision).** Damage is checked
when fauna moves adjacent to the player, not when the player moves adjacent to fauna.
If the player approaches a fauna between its move ticks, the player gets a free first
strike before the fauna's next cycle deals contact damage. This rewards aggressive play:
walk up → attack → attack → fauna dead before its second tick. Risk/reward.

**Shelter protection:** `HexGrid.get_tile(player.current_tile).structure == &"shelter"`
→ contact damage = 0. Shelter is `blocks_movement: false` — player walks onto it.

**Despawn (dawn signal):**

```
DayNightCycle emits dawn()
  │
  ├─ For each fauna: Emit fauna_despawned(id)
  ├─ _fauna.clear()
  └─ Done
```

#### Combat — Player Attacks Fauna

```
Player taps tile with fauna (adjacent)
  │
  ├─ Input priority (highest first):
  │     1. Fauna present → attack (this feature)
  │     2. Gatherable resource → gather (feature-003)
  │     3. Else → movement (feature-002)
  │
  ├─ Check attack cooldown (is_attacking flag):
  │     ✗ On cooldown → reject
  │
  ├─ Set is_attacking = true, start 1.0s timer
  │
  ├─ Determine damage:
  │     weapon = Inventory.get_tool(&"weapon")
  │     damage = WEAPON_DAMAGE.get(weapon, 5)
  │
  ├─ Apply: fauna.hp -= damage
  │
  ├─ Feedback: floating damage number (same pattern as gather)
  │
  ├─ if fauna.hp <= 0:
  │     Remove from _fauna
  │     Emit fauna_killed(id, coords)
  │       → SurvivalSystem listens: creates ground item
  │         { type: &"meat", amount: meat_drop_amount, coords: fauna.coords }
  │         Emits ground_item_dropped(coords, &"meat", 1)
  │       (FaunaManager does NOT write to SurvivalSystem._ground_items directly)
  │
  ├─ Timer expires → is_attacking = false
  └─ Done
```

**Meat drop ownership:** FaunaManager emits `fauna_killed`. SurvivalSystem listens and
creates the ground item in its own `_ground_items` array. No cross-system private state
access. FaunaManager knows nothing about ground items.

### Layers & Components

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       ├─ WorldEnvironment                      [feature-007]
       ├─ DirectionalLight3D                    [feature-007]
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ ResourceRenderer (Node3D)             [feature-003]
       ├─ StructureRenderer (Node3D)            ← NEW (MultiMesh per structure type)
       │    ├─ MultiMeshInstance3D [workbench]
       │    ├─ MultiMeshInstance3D [storage_chest]
       │    ├─ MultiMeshInstance3D [shelter]
       │    ├─ MultiMeshInstance3D [wall]
       │    └─ MultiMeshInstance3D [torch]
       ├─ FaunaRenderer (Node3D)                ← NEW (single MultiMesh)
       ├─ GroundItemRenderer (Node3D)           [feature-006]
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)
       │    ├─ GatherSystem (Node)              [feature-003]
       │    ├─ CraftingSystem (Node)            [feature-005]
       │    ├─ SurvivalSystem (Node)            [feature-006]
       │    ├─ BuildingSystem (Node)            ← NEW
       │    └─ FaunaManager (Node)              ← NEW
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ GatherFeedback (CanvasLayer)               [feature-003]
  └─ HUD (CanvasLayer)                          [feature-004]
       ├─ StatBars (HBoxContainer)              [feature-006]
       ├─ DayCounter (HBoxContainer)            [feature-007]
       ├─ InventoryButton                       [feature-004]
       ├─ BuildButton (TextureButton)           ← NEW (always visible)
       ├─ CraftButton                           [feature-005]
       ├─ InventoryPanel                        [feature-004]
       ├─ CraftingPanel                         [feature-005]
       └─ BuildPanel (PanelContainer)           ← NEW
            └─ ScrollContainer
                 └─ StructureList (VBoxContainer)
  └─ ScreenFade (CanvasLayer)                   [feature-006]
```

#### File Structure

```
scripts/
  building/
    building_system.gd       # Node (child of Player) — placement validation, build action,
                              #   placement mode state, is_placing flag
    structure_renderer.gd    # Node3D — MultiMesh per structure type
  fauna/
    fauna_manager.gd         # Node (child of Player) — spawn, AI, combat, despawn
    fauna_renderer.gd        # Node3D — MultiMesh for fauna

scenes/
  world/
    structure_renderer.tscn  # 5 MultiMeshInstance3D children
    fauna_renderer.tscn      # Single MultiMeshInstance3D

ui/
  build_panel.gd             # Control — structure list, triggers placement mode
  structure_entry_ui.gd      # Control — single structure row

data/
  structure_config.tres      # Resource — structure definitions
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `building_system.gd` | Child Node of Player. Placement validation, material consumption, `is_placing` flag, calls `HexGridRenderer.highlight_tiles()` / `clear_highlights()` during placement mode. Highest input priority when `is_placing`. | `HexGrid` (tile queries, structure_placed), `HexGridRenderer` (highlight API), `Inventory` (has_item, remove_item) |
| `fauna_manager.gd` | Child Node of Player. Spawn on `night`, AI movement in `_process`, contact damage, combat (`is_attacking` flag), despawn on `dawn`. | `DayNightCycle` (signals), `HexGrid` (tile queries), `Inventory` (get_tool for weapon) |
| `structure_renderer.gd` | Node3D under World. MultiMesh per structure type (~5 draw calls). Updates on `structure_placed`. Visibility follows tile fog. | `HexGrid` (structure_placed, fog signals) |
| `fauna_renderer.gd` | Node3D under World. Single MultiMesh, max ~3 instances (1 draw call). Updates on fauna signals. | `FaunaManager` (fauna signals) |
| `build_panel.gd` | Control on BuildPanel. Structure list with recipes + affordability. Triggers `building_system.enter_placement_mode(type)`. Mutual exclusion with Inventory/Crafting. | `BuildingSystem`, `Inventory` (has_item) |

#### Tile Highlight API — Feature-001 Amendment

HexGridRenderer exposes a highlight API for placement mode. BuildingSystem calls it;
HexGridRenderer owns the visual.

```gdscript
# Added to HexGridRenderer:
func highlight_tiles(coords: Array[Vector2i], color: Color) -> void
func clear_highlights() -> void
```

**Implementation:** HexGridRenderer uses the existing MultiMesh instance custom data
to flag highlighted tiles. The hex shader reads a highlight channel — if set, blends
the highlight color over the base biome material (e.g., cyan tint for valid placement).
This is a per-instance custom data update, not a new draw call. Zero draw call cost.

**Who calls it:**
- `building_system.enter_placement_mode(type)` → compute valid adjacent tiles →
  `HexGridRenderer.highlight_tiles(valid_tiles, Color.CYAN)`
- `building_system.exit_placement_mode()` → `HexGridRenderer.clear_highlights()`
- Player moves during placement mode → recalculate valid tiles → re-highlight

#### Input Priority — Full Stack

Normal mode (no placement, no gathering, no attacking):

```
process_priority (lower = runs first in _unhandled_input):
  1. BuildingSystem   [is_placing check — claims if placing]
  2. FaunaManager     [fauna on adjacent tile → attack]
  3. GatherSystem     [resource on adjacent tile → gather]
  4. PlayerInput      [movement — pathfind or joystick]
```

**Placement mode (`is_placing == true`):** BuildingSystem intercepts ALL taps.
- Tap valid highlighted tile → place structure, exit placement mode
- Tap non-valid area → exit placement mode (cancel)
- Tap Build button → exit placement mode (cancel)
- `set_input_as_handled()` prevents fall-through to fauna/gather/movement

**Normal mode (`is_placing == false`):** BuildingSystem passes through — does not
call `set_input_as_handled()`. Next in priority (FaunaManager) gets the event.

This means BuildingSystem always has the lowest `process_priority` value (runs first)
but only claims input when `is_placing == true`. Clean gating.

#### Signal Wiring

```
DayNightCycle signals                    fauna_manager.gd
  night()                            ──►  spawn fauna (if day >= 4)
  dawn()                             ──►  despawn all fauna

fauna_manager.gd                         survival_system.gd
  fauna_killed(id, coords)           ──►  create meat ground item
  fauna_attacked_player(id, damage)  ──►  apply HP damage to player

building_system.gd                       HexGrid
  (build action)                     ──►  structure_placed(coords, type)

building_system.gd                       HexGridRenderer
  enter_placement_mode               ──►  highlight_tiles(valid, CYAN)
  exit_placement_mode                ──►  clear_highlights()

HexGrid signals                          structure_renderer.gd
  structure_placed(coords, type)     ──►  add structure instance

fauna_manager.gd                         fauna_renderer.gd
  fauna_spawned(id, coords)          ──►  add instance
  fauna_moved(id, from, to)          ──►  update transform
  fauna_killed(id, coords)           ──►  remove instance
  fauna_despawned(id)                ──►  remove instance
```

#### Panel Mutual Exclusion — Three Panels

```gdscript
# build_panel.gd._ready():
inventory_panel.panel_opened.connect(close)
crafting_panel.panel_opened.connect(close)

# inventory_panel.gd._ready() — add:
build_panel.panel_opened.connect(close)

# crafting_panel.gd._ready() — add:
build_panel.panel_opened.connect(close)
```

#### Draw Call Budget — Final Tally

| Renderer | Draw Calls | Notes |
|----------|-----------|-------|
| HexGridRenderer | ~5 | One per biome |
| ResourceRenderer | ~6 | One per resource type |
| StructureRenderer | ~5 | One per structure type |
| FaunaRenderer | 1 | Max ~3 instances |
| GroundItemRenderer | 1 | Max ~10 instances |
| Player | 1 | Single mesh |
| **Total** | **~19** | Well within <100 budget |

### UI Specs

#### Build Panel — Bottom Drawer

Same pattern as Inventory (feature-004) and Crafting (feature-005).

```
┌──────────────────────────┐
│ [♥ ████████░░]           │
│ [🍖 █████░░░░]           │
│ [💧 ████░░░░░]  DAY 07 ☀ │
│                          │
│      (game world visible)│  ← ~55% of screen
│                          │
├──────────────────────────┤
│  BUILD               [X] │
│ ─────────────────────────│
│ ┌──────────────────────┐ │
│ │ Workbench            │ │
│ │  Wood: 3/5  Stone: 2/3 │ │  ← owned/needed
│ │                [BUILD]│ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ Wall                 │ │
│ │  Wood: 5/3     [BUILD]│ │  ← affordable
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │  ← ~45% height, scrollable
│ │ Shelter              │ │
│ │  Wood: 3/10 ...  [--]│ │  ← greyed
│ └──────────────────────┘ │
└──────────────────────────┘
```

#### Structure Entry States

| State | Visual | Build Button |
|-------|--------|-------------|
| Affordable | Full brightness, ingredients green | Active — enters placement mode |
| Unaffordable | Dimmed, short ingredients red | Greyed — not tappable |

No "already owned" state. Structures can be placed multiple times (multiple walls,
torches, etc.). Unlike tools which are one-per-slot.

#### Placement Mode Overlay

When player taps BUILD on a structure:
- Panel closes (world visible for tile selection)
- Valid adjacent tiles highlighted cyan (via `HexGridRenderer.highlight_tiles()`)
- Floating label centered above player: **"TAP TO PLACE WALL"**
  - Font: Space Grotesk, uppercase, tracking-widest
  - Color: primary (#a8e8ff) at 60% opacity
  - 1px dark outline for readability (no drop shadow)
  - Styled per Tactical Brutalism — mil-spec, not generic tooltip
- Tap highlighted tile → place, clear highlights, label disappears
- Tap elsewhere or Build button → cancel, clear highlights, label disappears

#### Combat & Damage Feedback

**Attack feedback — floating damage numbers:**

Reuses GatherFeedback CanvasLayer (feature-003). Same system, different content:
- Gather: "+1 WOOD" in green, rises and fades
- Attack: "-10" in red, rises and fades from fauna position

GatherFeedback becomes a shared floating-text system. No rename needed — the
component spawns a label at a screen position with configurable text and color.

```gdscript
# GatherFeedback API (extended):
func show_floating_text(world_pos: Vector3, text: String, color: Color) -> void
```

Callers:
- GatherSystem: `show_floating_text(pos, "+1 Wood", Color.GREEN)`
- FaunaManager: `show_floating_text(pos, "-10", Color.RED)`

**Player hit feedback — red vignette flash:**

When fauna deals contact damage, a brief red screen-edge flash alerts the player
that they're taking damage. Reuses ScreenFade CanvasLayer (feature-006):

```gdscript
# ScreenFade API (extended):
func flash(color: Color, duration: float = 0.2) -> void
```

- Red vignette: `ScreenFade.flash(Color(1, 0, 0, 0.3), 0.2)`
- ColorRect alpha 0 → 0.3 → 0 over 0.2s. Semi-transparent red, screen edges only
  (radial gradient or simple full-screen tint).
- 10 HP per hit is significant — player must notice beyond stat bar decrease.

**ScreenFade now has three uses:**
1. `fade_out()` / `fade_in()` — death transition (feature-006)
2. `flash()` — damage feedback (this feature)
3. Future: save/load transitions

#### Touch Targets

- Structure entry height: ~100px (same as crafting)
- BUILD button in entry: ~80×48px
- BuildButton (HUD): 64×64px
- Close button: 48×48px
- Placement mode: tap targets are hex tiles (~54-72px, above 48dp min)

#### Consistency

- Same bottom-drawer (full width, ~45% height)
- Same close behavior (X, tap outside, toggle button)
- Same semi-transparent background
- Mutual exclusion with Inventory and Crafting panels
- Game continues running — no pause
- ScrollContainer wraps StructureList
