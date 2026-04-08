# Resource Gathering

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F3, §9 AC3 | /aid-interview |
| 2026-03-30 | Data Model written — resource config table, direct tool matching, respawn queue | /aid-specify |
| 2026-03-30 | Feature Flow written — gather/move disambiguation, cancel, multi-resource priority | /aid-specify |
| 2026-03-30 | Layers & Components written — MultiMesh resources, is_gathering flag | /aid-specify |
| 2026-03-31 | Audit fixes applied (see delivery DETAIL.md) | /audit |
| 2026-03-31 | Round 2 fixes: tool-gated feedback + movement, equipped var, stale deps | /audit |

## Source

- REQUIREMENTS.md §5 F3 (Resource Gathering)
- REQUIREMENTS.md §9 AC3 (Gathering acceptance criteria)
- REQUIREMENTS.md §10 P0 — Core Loop

## Description

Players gather resources by tapping resource nodes on adjacent hex tiles. Resources are tool-gated: bare hands yield basic materials (Wood, Berries, Fiber), while crafted tools (Stone Axe, Stone Pickaxe) unlock higher-tier resources (thick trees, Ore, Crystals) and speed up gathering. Resource nodes deplete after a number of gathers and visually change. Depleted resources regenerate on tiles outside the player's visible range after a type-specific timer; resources never respawn while the tile is visible.

## User Stories

- As a player, I want to gather resources by tapping so the interaction is simple and satisfying
- As a player, I want better tools to unlock new resources so I feel progression
- As a player, I want resources to respawn off-screen so I'm never permanently stuck

## Priority

Must (P0 — Core Loop)

## Acceptance Criteria

- [ ] Tap tree with bare hands → +1 Wood in inventory
- [ ] Tap ore with bare hands → nothing happens (tool-gated)
- [ ] Tap ore with Stone Pickaxe equipped → +1 Ore
- [ ] Resource node depletes after N gathers and visually changes
- [ ] Depleted resource on non-visible tile regenerates after type-specific timer

## Save Integration

Adds per-tile resource state (type, remaining gathers, respawn timers) to save data.

---

## Technical Specification

### Data Model

#### Additions to PropNode (defined in feature-001)

Feature-001 defined `PropNode` with: `type`, `remaining`, `max_amount`, `tool_required`.

This feature adds one property:

| Property | Type | Description |
|----------|------|-------------|
| `respawn_time` | `float` | Seconds until respawn after depletion (0 = no respawn). Set by worldgen from BiomeData. |

No other per-node additions. `gather_time` and `gather_amount` are resource-type
properties, not per-node — they live in the resource config table (see below).

#### Resource Config Table

A single data Dictionary (or Resource file) keyed by resource type. Looked up at gather
time — not stored per `PropNode` instance.

```gdscript
# resource_config: Dictionary[StringName, Dictionary]
{
  &"wood":    { "gather_time": 1.0, "gather_amount": 1 },
  &"berries": { "gather_time": 0.5, "gather_amount": 1 },
  &"fiber":   { "gather_time": 0.5, "gather_amount": 1 },
  &"stone":   { "gather_time": 1.5, "gather_amount": 1 },
  &"ore":     { "gather_time": 2.0, "gather_amount": 1 },
  &"crystal": { "gather_time": 2.5, "gather_amount": 1 },
}
```

Values are tunable without touching gather logic. Lives alongside BiomeData in the
`data/` directory (e.g., `data/resource_config.tres` or a static Dictionary in a
constants file).

#### Tool Speed Multipliers

A separate data Dictionary — tool × resource type → speed multiplier:

```gdscript
# tool_speed: Dictionary[StringName, Dictionary[StringName, float]]
# Key: equipped tool. Value: resource type → multiplier (default 1.0 if absent).
{
  &"stone_axe":     { &"wood": 0.5 },      # halves wood gather time
  &"stone_pickaxe": { &"stone": 0.5 },      # halves stone gather time
}
```

Effective gather time: look up the relevant tool slot for the resource type, get the
equipped tool name, then `resource_config[type].gather_time * tool_speed.get(tool, {}).get(type, 1.0)`

#### Tool-Gating — Direct StringName Matching (via Inventory)

No tier system. MVP uses direct matching between `PropNode.tool_required` and
the tool in the corresponding Inventory slot. Gathering queries tool slots via
`Inventory.get_tool()`, not a player property:

```gdscript
# Check if player can gather a resource node:
func can_gather(node: PropNode, inventory: Inventory) -> bool:
    if node.tool_required == &"":
        return true  # bare hands
    var slot = item_config[node.tool_required].get("tool_slot", &"")
    return inventory.get_tool(slot) == node.tool_required
```

`Player.equipped_tool` is eliminated. Tool slots are owned by Inventory (feature-004).

#### Respawn Queue

Tracks depleted resource nodes waiting to regenerate. Managed by the gathering system
as a runtime array — not stored on tiles.

```gdscript
var _respawn_queue: Array[Dictionary]
# Each entry:
# {
#   "coords": Vector2i,      # tile location
#   "resource_index": int,    # index into tile.prop_nodes
#   "time_remaining": float,  # seconds until respawn
# }
```

**Respawn rule:** Timer only ticks while tile `fog_state != VISIBLE`. If the player
returns to a depleted tile (tile becomes VISIBLE), the timer pauses. Resumes when
tile goes back to REVEALED or HIDDEN.

Why Dictionary array, not Resource: Transient runtime entries — created on depletion,
removed on respawn. No scene tree presence, no type safety needed. Simple and
allocation-light.

#### Save Data Addition

Respawn queue saved so depleted resources survive app restarts:

```json
{
  "respawn_queue": [
    { "tile_col": 3, "tile_row": -2, "resource_index": 0, "time_remaining": 45.2 }
  ]
}
```

`PropNode.remaining` values are already saved per-tile (feature-001). The respawn
queue is the only new save data from this feature.

### Feature Flow

#### Tap Input Disambiguation — Gather vs Move

**Design rule (explicit):** Tapping an adjacent tile with gatherable resources triggers
gathering, not movement. To walk onto a resource tile, use the joystick. This is
intentional — tap = interact, joystick = move.

The full decision tree for a tile tap:

```
Tap resolves to target_coords
  │
  ├─ Is target adjacent to player.current_tile?
  │    │
  │    ├─ YES: Check for gatherable resources on target tile
  │    │    │
  │    │    ├─ Has resource with remaining > 0 AND can_gather(node, equipped_tool)?
  │    │    │    → GATHER (claim tap, begin gather action)
  │    │    │
  │    │    ├─ Has resources but ALL are tool-gated (wrong tool) or depleted?
  │    │    │    → SHOW FLOATING "REQUIRES [TOOL]" FEEDBACK, THEN FALL THROUGH TO MOVEMENT
  │    │    │
  │    │    └─ No resources on tile?
  │    │         → FALL THROUGH TO MOVEMENT
  │    │
  │    └─ NO (not adjacent):
  │         → MOVEMENT (pathfind, feature-002)
  │
```

**Key rule:** Wrong tool = show requirement feedback and move. The player is never
stuck. Floating "REQUIRES [TOOL]" text appears in red, then the tap falls through
to movement — player walks to the tile while feedback floats.

#### Multi-Resource Priority

When a tile has multiple resource nodes with `remaining > 0` that the player can gather,
pick the **highest tool requirement** first:

```
Priority order (descending):
  1. Nodes requiring stone_pickaxe (ore, crystal — rarest)
  2. Nodes requiring stone_axe (thick trees — mid-tier)
  3. Nodes requiring bare hands (wood, berries, fiber — common)
```

Implementation: sort gatherable nodes by a static priority Dictionary keyed on
`tool_required`. Pick the first. If the player wants a lower-priority resource, they
unequip the tool (equip bare hands) — the priority changes because different nodes
pass `can_gather`.

```gdscript
const TOOL_PRIORITY: Dictionary = {
    &"stone_pickaxe": 2,
    &"stone_axe": 1,
    &"": 0,
}
```

#### Gather Action

```
Gather begins (target_coords, prop_node determined):
  │
  ├─ Set gather_system.is_gathering = true (player locked — movement rejects input)
  │     Face toward target tile
  │     Play gather animation (placeholder: simple bob/swing toward tile)
  │
  ├─ Compute effective gather time:
  │     tool_slot = item_config[node.tool_required].get("tool_slot", &"")
  │     equipped = Inventory.get_tool(tool_slot) if tool_slot else &""
  │     base = resource_config[node.type].gather_time
  │     multiplier = tool_speed.get(equipped, {}).get(node.type, 1.0)
  │     effective_time = base * multiplier
  │
  ├─ Start gather timer (Tween duration = effective_time)
  │
  ├─ CANCEL CHECK — any input during gather cancels:
  │     Tap anywhere OR joystick input → kill tween,
  │     set is_gathering = false, no resource gained, no depletion.
  │
  ├─ On timer complete (not cancelled):
  │     node.remaining -= 1
  │     amount = resource_config[node.type].gather_amount
  │
  │     Inventory.add_item(node.type, amount) → bool
  │       ✗ false (inventory full) → item lost (feature-004 defines rejection UX)
  │       ✓ true → item added
  │
  │     Visual feedback:
  │       Floating "+{amount} {type}" text — rises from tile, fades over ~1s
  │       (Label3D or screen-space Label spawned at gather point)
  │
  │     Sound: play gather-complete SFX (placeholder hook, asset out of scope)
  │
  │     if node.remaining == 0:
  │       Emit HexGrid.resource_depleted(target_coords, node.type)
  │       Visual: resource node changes appearance (tree → stump, rock → rubble)
  │       if node.respawn_time > 0:
  │         _respawn_queue.append({
  │           "coords": target_coords,
  │           "resource_index": idx,
  │           "time_remaining": node.respawn_time
  │         })
  │
  └─ Set is_gathering = false — player unlocked, can move or gather again
```

**Gather lock via `is_gathering` flag:** Gathering does not extend the movement state
machine. Instead, `gather_system.gd` exposes an `is_gathering: bool` property.
Feature-002's movement system checks this flag and rejects all movement input while
true. This keeps gathering and movement decoupled — gathering is a lock that prevents
movement, not a movement mode.

```
gather_system.is_gathering == true
  → player_input rejects tap-to-move and joystick
  → gather_system handles cancel (any input → is_gathering = false)
```

#### Respawn System

```
Every frame (_process on gathering system):
  │
  For each entry in _respawn_queue:
  │
  ├─ tile = HexGrid.get_tile(entry.coords)
  │
  ├─ if tile.fog_state == VISIBLE:
  │     Skip — timer paused (player is watching this tile)
  │
  ├─ else (REVEALED or HIDDEN):
  │     entry.time_remaining -= delta
  │
  │     if time_remaining <= 0:
  │       node = tile.prop_nodes[entry.resource_index]
  │       node.remaining = node.max_amount
  │       Remove entry from _respawn_queue
  │       Emit HexGrid.resource_respawned(entry.coords, node.type)
  │       → Renderer updates visual (if tile is REVEALED, restored resource
  │         appears next time player moves adjacent)
  │
  └─ End loop
```

**Performance:** At most ~50–100 respawn entries at any time. Per-frame iteration of
a small array is negligible.

**Edge cases:**
- Player depletes, walks away, returns before respawn → timer pauses while VISIBLE,
  resumes when they leave. Player sees depleted node while visiting.
- Save/load mid-respawn → queue serialized, timers resume from saved values on load.
- Resource with `respawn_time == 0` → never enters queue, permanently depleted.

#### Gather Feedback

| Feedback | Implementation | When |
|----------|---------------|------|
| Floating text | "+1 Wood" rises and fades (~1s). Label3D or screen-space Label. | On successful gather |
| Node visual change | Swap resource appearance (tree→stump, rock→rubble, bush→bare). | On depletion (remaining hits 0) |
| Node visual restore | Swap back to full appearance. | On respawn |
| Sound | Play SFX at gather-complete. Placeholder hook. | On successful gather |
| Tool-gated feedback | Floating "REQUIRES [TOOL]" text in red (same GatherFeedback system). | On tap with wrong tool |

### Layers & Components

#### Scene Tree Additions

```
Main (Node)
  └─ World (Node3D)
       ├─ HexGridRenderer (Node3D)             [feature-001]
       │    └─ (MultiMeshInstance3D × 5 biomes)
       ├─ PropRenderer (Node3D)             ← NEW
       │    ├─ MultiMeshInstance3D [wood/tree]
       │    ├─ MultiMeshInstance3D [stone/rock]
       │    ├─ MultiMeshInstance3D [berries/bush]
       │    ├─ MultiMeshInstance3D [fiber/grass]
       │    ├─ MultiMeshInstance3D [ore/vein]
       │    └─ MultiMeshInstance3D [crystal/cluster]
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)
       │    └─ GatherSystem (Node)              ← NEW
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ GatherFeedback (CanvasLayer)               ← NEW
```

#### File Structure

```
scripts/
  gathering/
    gather_system.gd        # Node (child of Player) — gather action, respawn queue,
                             #   input claim, is_gathering flag
    prop_renderer.gd    # Node3D — MultiMesh per resource type, signal-driven updates

scenes/
  world/
    prop_renderer.tscn  # Scene — 6 MultiMeshInstance3D children

ui/
  gather_feedback.gd        # CanvasLayer — floating "+1 Wood" labels

data/
  resource_config.tres      # Resource — gather_time, gather_amount per resource type
  tool_config.tres          # Resource — tool speed multipliers per resource type
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `gather_system.gd` | Child Node of Player. Owns `is_gathering` flag, gather action lifecycle (start, cancel, complete), respawn queue tick, input disambiguation (claim tap vs fall through to movement). | `HexGrid` (API + signals), `Player` (current_tile), `Inventory` (get_tool, add_item) |
| `prop_renderer.gd` | Manages one `MultiMeshInstance3D` per resource type (~6 types = ~6 draw calls). Spawns/hides/swaps resource visuals based on HexGrid signals. Event-driven, no per-frame work. | `HexGrid` (signals only) |
| `gather_feedback.gd` | CanvasLayer. Spawns floating "+N Type" labels at screen position of gathered tile. Labels tween up + fade, then `queue_free`. | Screen position from `Camera3D.unproject_position()` |

#### Signal Wiring

```
HexGrid signals                          gather_system.gd
  map_generated()                    ──►  initial setup (nothing to gather yet, but ready)
  resource_depleted(coords, type)     ◄── (gather_system emits via HexGrid on depletion)
  resource_respawned(coords, type)    ◄── (gather_system emits via HexGrid on respawn)

HexGrid signals                          prop_renderer.gd
  map_generated()                    ──►  allocate MultiMesh instances for initial resources
  tile_revealed(coords)              ──►  add resource instances for newly discovered tile
  tile_visibility_changed(coords, s) ──►  show/hide resource instances per fog state
  resource_depleted(coords, type)    ──►  swap instance (tree mesh → stump mesh)
  resource_respawned(coords, type)   ──►  swap instance (stump mesh → tree mesh)

gather_system.gd                         gather_feedback.gd
  signal gather_completed(type, amt) ──►  spawn floating label

gather_system.gd                         player_input.gd (feature-002)
  is_gathering property              ──►  movement checks flag, rejects input while true
```

#### Resource Rendering — MultiMesh per Type

Same pattern as hex tile rendering (feature-001). One `MultiMeshInstance3D` per resource
type with a shared mesh and material. **~6 draw calls for all resource visuals** — well
within the remaining ~95 draw call budget after hex tiles.

**How it works:**

1. On `map_generated()`, prop_renderer allocates MultiMesh instances sized to the
   total count of each resource type across all tiles.
2. Each instance transform: position from `HexGrid.axial_to_world()` + small offset
   within the hex (resources don't sit dead-center — slight random offset per node for
   visual variety), Y from tile elevation.
3. Instance visibility via custom data (same pattern as hex tiles):
   - Tile HIDDEN → instance at zero scale (invisible)
   - Tile REVEALED/VISIBLE → full scale, custom data controls fog dim
4. On `resource_depleted` → swap the mesh variant via custom data flag (full → depleted).
   Implementation: use custom data channel to index into a mesh variant (0 = full tree,
   1 = stump). The shader reads this to select the variant, or use two separate
   MultiMesh pools per type (full + depleted) and move instances between them.
5. On `resource_respawned` → swap back (depleted → full).
6. On `tile_revealed` → add instances for newly visible tile's resources.

**Mesh details:** Simple 3D primitives per resource type (colored cylinder = tree,
grey box = rock, red sphere = berry bush). <500 tris each. Placeholder art for MVP.

#### Input Priority

`gather_system.gd` has a lower `process_priority` value than `player_input.gd` (lower value = higher priority in Godot) — it receives
`_unhandled_input` first. If it claims the tap (adjacent tile with gatherable resource),
it calls `get_viewport().set_input_as_handled()`. Otherwise, the event falls through
to `player_input.gd` for movement.

During an active gather (`is_gathering == true`), `gather_system.gd` intercepts any
input to trigger cancel. It calls `set_input_as_handled()` after cancelling — the
cancel input doesn't fall through to movement.

#### Gather Lock Integration with Movement (feature-002)

`gather_system.gd` exposes:

```gdscript
var is_gathering: bool = false
```

`player_input.gd` (feature-002) checks `gather_system.is_gathering` before processing
any movement input. If true, input is rejected (gather_system handles it for cancel).
This requires player_input to have a reference to gather_system — both are children of
Player, so `$"../GatherSystem"` or an injected reference in `_ready()`.

No changes to feature-002's MoveState enum. Gathering is a lock, not a movement mode.
