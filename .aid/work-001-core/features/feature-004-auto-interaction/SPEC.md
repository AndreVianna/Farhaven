# Auto-Interaction System

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Feature identified from REQUIREMENTS.md §5 F3, F9 (auto-defend portion), §9 AC3, AC9 (auto-defend criteria) | /aid-interview |
| 2026-03-31 | Full technical specification — all sections | /aid-specify |
| 2026-03-31 | Fixes: gather-always-completes, 7-tile check, chain from current pos, scan→check | /aid-specify |
| 2026-04-01 | I5: Fly-to-player animation updated to ~0.5s, marked [TUNING_REQUIRED] for HEX_SIZE=3.0 scale. M2: Resource offset specified as ±15% of HEX_SIZE radius. Range note: auto-gather area transitioning to circular world-unit [TUNING_REQUIRED]. | /pivot-cascade |

## Source

- REQUIREMENTS.md §5 F3 (Resource Gathering -- Auto-Interaction)
- REQUIREMENTS.md §5 F9 (Night Threats -- auto-defend portion)
- REQUIREMENTS.md §9 AC3 (Gathering acceptance criteria)
- REQUIREMENTS.md §9 AC9 (Night Threats -- auto-defend criteria)

## Description

The auto-interaction system handles all proximity-based player reactions. When the player moves adjacent to a cataloged resource, auto-gather starts. When a cataloged hostile creature is adjacent, auto-defend triggers (player auto-attacks with equipped weapon). Ground items are auto-picked up on tile entry. All auto-interactions require catalog status -- uncataloged elements (?) are inert to the auto-system. Tool-gating applies after catalog gate (e.g., cataloged ore still requires pickaxe).

## User Stories

- As a player, I want resources to gather automatically when I walk near them so I focus on exploration
- As a player, I want my character to defend themselves against known threats without me tapping
- As a player, I want to just walk around and have things happen -- movement IS interaction

## Priority

Must (P0 -- Core Loop)

## Acceptance Criteria

- [ ] Player moves adjacent to uncataloged resource (?) -> nothing happens (scan gate)
- [ ] Player scans unknown wood resource -> cataloged -> auto-gather starts on next proximity
- [ ] Player moves adjacent to cataloged wood -> auto-gather, +1 Wood in inventory
- [ ] Player moves adjacent to cataloged ore without Stone Pickaxe -> nothing (tool-gated)
- [ ] Player moves adjacent to cataloged ore with Stone Pickaxe -> auto-gather, +1 Ore
- [ ] Resource node depletes after N gathers and visually changes
- [ ] Depleted resource on non-visible tile regenerates after type-specific timer
- [ ] Uncataloged hostile fauna -> no auto-defend
- [ ] Cataloged hostile fauna adjacent -> auto-defend (player auto-attacks with equipped weapon)

## Save Integration

No save data. Respawn queue is intentionally not persisted — depleted resources respawn on load. Catalog state owned by feature-003.

---

## Technical Specification

### Data Model

#### Core Principle

**Movement IS interaction.** The player controls WHERE to go. The game handles the
rest. All interactions are proximity-based and catalog-gated:

- ❓ (uncataloged) = inert to the auto-system
- Cataloged = auto-interaction unlocked for that type forever
- No taps required for gathering, defending, or picking up items

#### ResourceNode Extension (feature-001 Resource)

Feature-001 defines `ResourceNode` with: `type`, `remaining`, `max_amount`, `tool_required`.
This feature adds:

| Property | Type | Description |
|----------|------|-------------|
| `respawn_time` | `float` | Seconds until respawn after depletion (0 = no respawn). Set by MapLoader from BiomeData. |

No other per-node additions. `gather_time` and `gather_amount` are resource-type
properties looked up from the resource config table at gather time.

#### Resource Config Table

Static data Dictionary keyed by resource type. Looked up during auto-gather — not
stored per `ResourceNode` instance.

```gdscript
# resource_config: Dictionary[StringName, Dictionary]
{
  &"wood":    { "gather_time": 1.0, "gather_amount": 1 },
  &"berries":        { "gather_time": 0.5, "gather_amount": 1 },
  &"toxic_berries":  { "gather_time": 0.5, "gather_amount": 1 },
  &"fiber":   { "gather_time": 0.5, "gather_amount": 1 },
  &"stone":   { "gather_time": 1.5, "gather_amount": 1 },
  &"ore":     { "gather_time": 2.0, "gather_amount": 1 },
  &"crystal": { "gather_time": 2.5, "gather_amount": 1 },
}
```

Lives in `data/resource_config.tres` or a static Dictionary.

#### Tool Speed Multipliers

```gdscript
# tool_speed: Dictionary[StringName, Dictionary[StringName, float]]
{
  &"stone_axe":     { &"wood": 0.5 },      # halves wood gather time
  &"stone_pickaxe": { &"stone": 0.5 },      # halves stone gather time
}
```

Effective gather time:
`resource_config[type].gather_time * tool_speed.get(tool, {}).get(type, 1.0)`

Tool looked up via `Inventory.get_tool(slot)` where slot is determined from
`item_config[tool_required].tool_slot`.

#### Tool-Gating — Direct StringName Matching

No tier system. Direct match between `ResourceNode.tool_required` and the tool in
the corresponding Inventory slot:

```gdscript
func can_gather(node: ResourceNode, inventory: Inventory) -> bool:
    if node.tool_required == &"":
        return true  # bare hands
    var slot = item_config[node.tool_required].get("tool_slot", &"")
    return inventory.get_tool(slot) == node.tool_required
```

- `tool_required == &""` → bare hands (wood, berries, fiber)
- `tool_required == &"stone_axe"` → needs stone_axe in axe slot
- `tool_required == &"stone_pickaxe"` → needs stone_pickaxe in pickaxe slot

Axes cannot mine ore. Pickaxes cannot chop trees. Exact match per tool name.

#### Weapon Damage Table (for auto-defend)

```gdscript
const WEAPON_DAMAGE: Dictionary = {
    &"survival_knife": 10,
    &"": 5,  # bare hands
}
```

Weapon looked up via `Inventory.get_tool(&"weapon")`.

#### Auto-Defend Config

```gdscript
const AUTO_DEFEND_CONFIG: Dictionary = {
    "attack_cooldown": 1.0,   # seconds between auto-attacks
    "attack_range": 1,        # hexes — adjacent only
}
```

#### AutoInteractionSystem Properties (on Node)

| Property | Type | Description |
|----------|------|-------------|
| `_is_gathering` | `bool` | Currently auto-gathering a resource (gather timer active) |
| `_gather_target_coords` | `Vector2i` | Tile being gathered from |
| `_gather_target_index` | `int` | Index into tile.resource_nodes |
| `_gather_tween` | `Tween` | Active gather timer (null when not gathering) |
| `_defend_cooldown` | `float` | Remaining seconds until next auto-attack (0 = ready) |
| `_respawn_queue` | `Array[Dictionary]` | Depleted resources awaiting respawn |

#### Respawn Queue Entry

```gdscript
# Each entry in _respawn_queue:
{
  "coords": Vector2i,      # tile location
  "resource_index": int,    # index into tile.resource_nodes
  "time_remaining": float,  # seconds until respawn
}
```

**Respawn rule:** Timer ticks only when tile `fog_state != VISIBLE`. Pauses when
player returns (VISIBLE), resumes on REVEALED/HIDDEN. Non-respawning resources
(`respawn_time == 0`) never enter queue.

#### Signals

```gdscript
# Auto-gather
signal auto_gather_started(coords: Vector2i, resource_type: StringName)
signal auto_gather_completed(coords: Vector2i, resource_type: StringName, amount: int)
signal auto_gather_failed(coords: Vector2i, reason: StringName)  # "tool_gated", "inventory_full", "not_cataloged"

# Auto-defend
signal auto_defend_triggered(fauna_id: int, damage: int)
signal auto_defend_cooldown_started(duration: float)

# Resource lifecycle
signal resource_depleted(coords: Vector2i, resource_type: StringName)  # forwarded to HexGrid
signal resource_respawned(coords: Vector2i, resource_type: StringName) # forwarded to HexGrid

# Ground item pickup
signal ground_item_picked_up(coords: Vector2i, type: StringName, amount: int)
```

#### Save Data

No save data from this feature. Respawn queue is intentionally NOT saved.
On load, all depleted resources respawn instantly — the world "heals" between
sessions. This is a small player-friendly bonus and avoids serializing timer state.
`ResourceNode.remaining` values are saved per-tile by feature-001 (they reset to
`max_amount` when respawn triggers on load). Catalog state owned by feature-003.

#### Cross-Feature Data Contracts

| This feature queries | Source | What it reads |
|---------------------|--------|---------------|
| `HexGrid.get_tile(coords).resource_nodes[]` | feature-001 | Resources on tile |
| `HexGrid.get_tile(coords).fog_state` | feature-001 | For respawn pause/resume |
| `Catalog.is_cataloged(entry_id)` | feature-003 | Catalog gate for auto-interaction. Queried per tile_entered, NOT via entry_cataloged signal. |
| `Catalog.get_entry(entry_id).properties` | feature-003 | Flora edible/toxic, fauna hostile, mineral tool_required |
| `Inventory.get_tool(slot)` | feature-005 | Tool for can_gather + weapon for auto-defend |
| `Inventory.add_item(type, amount)` | feature-005 | Store gathered resources |
| FaunaManager fauna positions + species | feature-010 | Adjacent hostile check for auto-defend |

| This feature is consumed by | Consumer | What it provides |
|-----------------------------|----------|-----------------|
| feature-012 (HUD) | `auto_gather_completed` / `auto_gather_failed` → floating text feedback |
| feature-001 (HexGrid) | `resource_depleted` / `resource_respawned` → tile state update |
| feature-003 (scanner) | Passive: resource renderer updates depend on gather depletion |

---

### Feature Flow

#### Auto-Gather Flow (proximity-triggered)

```
HexGrid emits tile_entered(coords) — player moved to a new tile
  │
  ├─ AutoInteractionSystem receives signal
  │
  ├─ Check current tile + ALL adjacent tiles (player tile + 6 neighbors = 7 tiles).
  │   **[TUNING_REQUIRED]** — Range system is transitioning from hex-distance to
  │   world-unit circular areas. Auto-gather will be "player's immediate vicinity"
  │   (circular area, radius TBD). This may reduce from 7 tiles to current-tile-only
  │   or a small circular radius. Flag for playtesting.
  │     For each tile in [current_tile] + HexGrid.get_neighbors(coords):
  │       For each resource_node in tile.resource_nodes:
  │         if resource_node.remaining <= 0: skip (depleted)
  │
  │         entry_id = RESOURCE_TO_ENTRY[resource_node.type]  (from feature-003)
  │         if NOT Catalog.is_cataloged(entry_id): skip (catalog gate — ❓)
  │
  │         if NOT can_gather(resource_node, Inventory): skip (tool gate)
  │
  │         → Found a gatherable, cataloged resource! Add to candidates list.
  │
  ├─ Sort candidates: TOOL_PRIORITY (highest first), then nearest to player
  ├─ If no candidates: return (nothing to do)
  │
  ├─ Begin auto-gather on best candidate:
  │     _is_gathering = true
  │     _gather_target_coords = candidate.tile.coords
  │     _gather_target_index = candidate.resource_index
  │
  │     Compute effective gather time:
  │       tool_slot = item_config[node.tool_required].get("tool_slot", &"")
  │       equipped = Inventory.get_tool(tool_slot) if tool_slot else &""
  │       base = resource_config[node.type].gather_time
  │       multiplier = tool_speed.get(equipped, {}).get(node.type, 1.0)
  │       effective_time = base * multiplier
  │
  │     Emit auto_gather_started(coords, node.type)
  │     Play resource "harvesting" animation on the resource node
  │     Create Tween: _gather_tween, duration = effective_time
  │
  │     ** GATHER ALWAYS COMPLETES. ** No cancel, no range check after start.
  │     Player can walk away freely — gather tween runs to completion regardless
  │     of distance. This is the core MLU feel: keep moving, stuff flows in.
  │
  ├─ On Tween complete (player may be anywhere):
  │     node.remaining -= 1
  │     amount = resource_config[node.type].gather_amount
  │     added = Inventory.add_item(node.type, amount)
  │
  │     if added > 0:
  │       Emit auto_gather_completed(coords, node.type, added)
  │       → Visual: resource visually "flies to" player's CURRENT position
  │         (not where they were when gather started). Tween from resource
  │         world position to Player.position over ~0.5s. **[TUNING_REQUIRED]** —
  │         at HEX_SIZE=3.0 fly distance is ~3× larger; scale duration with distance.
  │       → HUD (feature-012): floating "+1 Wood" text at player position
  │       → Sound: gather "ding" at player position
  │     else:
  │       Emit auto_gather_failed(coords, &"inventory_full")
  │       → HUD: floating "INVENTORY FULL" red text
  │
  │     if node.remaining == 0:
  │       Emit resource_depleted(coords, node.type) → forward to HexGrid
  │       if node.respawn_time > 0:
  │         _respawn_queue.append({ coords, resource_index, time_remaining: node.respawn_time })
  │
  │     _is_gathering = false
  │     _gather_tween = null
  │
  │     → CHAIN: re-check from player's CURRENT position (7 tiles: current + 6 neighbors).
  │       Player may have moved during gather. Chain finds next best resource adjacent
  │       to wherever the player NOW stands. Priority: TOOL_PRIORITY first, then nearest.
  │       If candidate found → start next gather immediately. Fluid chain continues
  │       as long as player is near cataloged resources.
  │
  └─ End
```

**Key design principles:**

- **No tap required.** Gathering triggers on `tile_entered`, not on tap. Movement IS
  interaction.
- **No movement lock.** `_is_gathering` does NOT block movement. Auto-gather runs
  concurrently. Player can walk away freely — gather always completes.
- **Gather always completes.** Once started, no cancel, no range check. The resource
  visually "flies to" the player's current position regardless of distance. This is
  the core MLU feel: keep moving, stuff flows in.
- **No cancel mechanism.** Pre-redesign had "any input cancels gather." Auto-gather
  just completes. Period.
- **Catalog gate.** Before tool_required, check `Catalog.is_cataloged()`. ❓ = inert.
- **Chain gathering.** After completing, re-check from player's CURRENT position.
  Player walking through a forest auto-gathers wood continuously, resources flying in.
- **Checks 7 tiles.** Current tile the player stands on + 6 adjacent neighbors.

**Multi-resource priority:** When multiple candidates exist, sort by:

1. `TOOL_PRIORITY` — highest tool_required first (rarest resource wins)
2. Distance — nearest to player's current tile (among equal priority)

```gdscript
const TOOL_PRIORITY: Dictionary = {
    &"stone_pickaxe": 2,
    &"stone_axe": 1,
    &"": 0,
}
```

#### Auto-Defend Flow (proximity-triggered)

```
FaunaManager emits fauna_moved(fauna_id, from_coords, to_coords)
  OR HexGrid emits tile_entered(player_coords) — player moved near fauna
  │
  ├─ AutoInteractionSystem checks: is any cataloged hostile fauna adjacent to player?
  │
  │     For each fauna (from FaunaManager query):
  │       if HexGrid.distance(player.current_tile, fauna.coords) > AUTO_DEFEND_CONFIG.attack_range:
  │         skip (too far)
  │       entry_id = fauna.species_type  (StringName matching catalog entry)
  │       if NOT Catalog.is_cataloged(entry_id): skip (unknown — no auto-defend)
  │       entry = Catalog.get_entry(entry_id)
  │       if NOT entry.properties.hostile: skip (passive creature)
  │       → Found an adjacent, cataloged, hostile fauna!
  │
  ├─ if _defend_cooldown > 0: return (on cooldown from last auto-attack)
  │
  ├─ Auto-attack:
  │     weapon = Inventory.get_tool(&"weapon")
  │     damage = WEAPON_DAMAGE.get(weapon, 5)  # bare hands = 5
  │     Face player toward fauna
  │     Emit auto_defend_triggered(fauna_id, damage)
  │       → FaunaManager receives: apply damage to fauna, handle kill if HP ≤ 0
  │       → HUD (feature-012): floating "-10" red text from fauna position
  │     _defend_cooldown = AUTO_DEFEND_CONFIG.attack_cooldown (1.0s)
  │     Emit auto_defend_cooldown_started(1.0)
  │
  └─ End
```

**Auto-defend triggers on TWO events:**
1. `fauna_moved` — fauna walks adjacent to player → auto-defend fires
2. `tile_entered` — player walks adjacent to cataloged hostile → auto-defend fires

**Cooldown tick:** `_defend_cooldown -= delta` in `_process`. Resets to 0 when expired.
Auto-defend only fires when cooldown is 0.

**Uncataloged hostile fauna:** Auto-defend does NOT fire. The fauna attacks the player
(surprise damage, handled by feature-010). Feature-003 auto-catalogs the species on
first hit. On the NEXT fauna_moved tick (1.0s later), auto-defend fires because the
species is now cataloged.

**Passive fauna:** Auto-defend ignores them. `entry.properties.hostile == false` → skip.

#### Auto-Pickup Flow (ground items)

```
HexGrid emits tile_entered(coords) — player arrived at tile
  │
  ├─ AutoInteractionSystem checks SurvivalSystem._ground_items for this tile
  │     (ground items are death drops from feature-007)
  │
  ├─ For each ground item at coords:
  │     added = Inventory.add_item(item.type, item.amount)
  │     if added == item.amount:
  │       Remove entry from _ground_items
  │       Emit ground_item_picked_up(coords, type, amount)
  │     elif added > 0:
  │       item.amount -= added (partial pickup)
  │       Emit ground_item_picked_up(coords, type, added)
  │     else:
  │       skip (inventory full)
  │
  └─ Done — no tap, no feedback beyond inventory update
```

**Ownership note:** Ground items are owned by feature-007 (SurvivalSystem). This
feature reads `_ground_items` and calls `Inventory.add_item`. Feature-007 exposes
a `get_ground_items_at(coords)` and `remove_ground_item()` API rather than direct
array access.

#### Respawn Queue Tick

```
Every frame (AutoInteractionSystem._process):
  │
  ├─ _defend_cooldown = max(0.0, _defend_cooldown - delta)
  │
  ├─ For each entry in _respawn_queue:
  │     tile = HexGrid.get_tile(entry.coords)
  │     if tile.fog_state == FogState.VISIBLE:
  │       skip (timer paused — player watching)
  │     else:
  │       entry.time_remaining -= delta
  │       if entry.time_remaining <= 0:
  │         node = tile.resource_nodes[entry.resource_index]
  │         node.remaining = node.max_amount
  │         Remove entry from _respawn_queue
  │         Emit resource_respawned(entry.coords, node.type) → forward to HexGrid
  │
  └─ End
```

**Performance:** ~50-100 respawn entries max. Small array iteration, negligible.

#### Gather Feedback (via HUD feature-012)

| Event | Signal | HUD Reaction |
|-------|--------|-------------|
| Successful gather | `auto_gather_completed(coords, type, amount)` | Floating "+1 Wood" green text |
| Inventory full | `auto_gather_failed(coords, &"inventory_full")` | Floating "INVENTORY FULL" red text |
| Tool-gated (uncataloged) | No signal (silently skipped — ❓ is inert) | ❓ icon stays visible |
| Tool-gated (cataloged, wrong tool) | `auto_gather_failed(coords, &"tool_gated")` | Floating "REQUIRES [TOOL]" red text |
| Auto-defend | `auto_defend_triggered(fauna_id, damage)` | Floating "-10" red text from fauna |

---

### Layers & Components

#### Scene Tree Additions

```
Main (Node)
  └─ World (Node3D)
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ ElementIconRenderer (Node3D)          [feature-003]
       ├─ ScanProgressRenderer (Node3D)         [feature-003]
       ├─ ResourceRenderer (Node3D)             ← NEW (MultiMesh per resource type)
       │    ├─ MultiMeshInstance3D [wood/tree]
       │    ├─ MultiMeshInstance3D [stone/rock]
       │    ├─ MultiMeshInstance3D [berries/bush]
       │    ├─ MultiMeshInstance3D [fiber/grass]
       │    ├─ MultiMeshInstance3D [ore/vein]
       │    └─ MultiMeshInstance3D [crystal/cluster]
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)
       │    ├─ ScannerSystem (Node)             [feature-003]
       │    └─ AutoInteractionSystem (Node)     ← NEW
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ HUD (CanvasLayer)                          [feature-012]
```

#### File Structure

```
scripts/
  auto_interaction/
    auto_interaction_system.gd  # Node (child of Player) — auto-gather, auto-defend,
                                 #   auto-pickup, respawn queue, _process tick

  rendering/
    resource_renderer.gd        # Node3D — MultiMesh per resource type, signal-driven

scenes/
  world/
    resource_renderer.tscn      # 6 MultiMeshInstance3D children

data/
  resource_config.tres          # gather_time, gather_amount per resource type
  tool_config.tres              # tool speed multipliers
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `auto_interaction_system.gd` | Child Node of Player. Proximity detection on `tile_entered` and `fauna_moved`. Auto-gather (catalog gate → tool gate → tween timer → inventory add → chain). Auto-defend (catalog gate → hostile check → cooldown → damage signal). Auto-pickup (ground items via feature-007 API). Respawn queue tick. | `HexGrid` (tile queries, signals), `Catalog` feature-003 (`is_cataloged`, `get_entry`), `Inventory` feature-005 (`get_tool`, `add_item`), `FaunaManager` feature-010 (fauna queries + `fauna_moved` signal), `SurvivalSystem` feature-007 (`get_ground_items_at`) |
| `resource_renderer.gd` | Node3D under World. One MultiMeshInstance3D per resource type (~6 draw calls). On `map_generated`: spawn instances. On `tile_revealed`/`tile_visibility_changed`: show/hide per fog. On `resource_depleted`: swap mesh (tree→stump). On `resource_respawned`: swap back. Per-node random offset within hex. | `HexGrid` (signals: map_generated, tile_revealed, tile_visibility_changed, resource_depleted, resource_respawned) |

#### Signal Wiring — Complete

```
HexGrid signals                              auto_interaction_system.gd
  tile_entered(coords)                   ──►  check current + adjacent for auto-gather + auto-pickup

FaunaManager (feature-010)                   auto_interaction_system.gd
  fauna_moved(id, from, to)              ──►  check if now adjacent for auto-defend

auto_interaction_system.gd                   FaunaManager (feature-010)
  auto_defend_triggered(fauna_id, dmg)   ──►  apply damage to fauna

auto_interaction_system.gd                   HexGrid
  resource_depleted(coords, type)        ──►  update tile state
  resource_respawned(coords, type)       ──►  update tile state

auto_interaction_system.gd                   feature-012 (HUD)
  auto_gather_completed(...)             ──►  floating "+1 Wood" text
  auto_gather_failed(...)                ──►  floating "INVENTORY FULL" / "REQUIRES [TOOL]" text
  auto_defend_triggered(...)             ──►  floating "-10" damage text

auto_interaction_system.gd                   resource_renderer.gd
  (via HexGrid resource_depleted)        ──►  swap mesh (tree → stump)
  (via HexGrid resource_respawned)       ──►  swap back (stump → tree)

HexGrid signals                              resource_renderer.gd
  map_generated()                        ──►  allocate MultiMesh instances
  tile_revealed(coords)                  ──►  add resource instances for tile
  tile_visibility_changed(coords, state) ──►  show/hide per fog
```

#### Resource Rendering — MultiMesh per Type

Same proven pattern as hex tiles (feature-001) and element icons (feature-003).

One `MultiMeshInstance3D` per resource type (~6 types = ~6 draw calls). Placeholder
meshes: colored cylinder (tree), grey box (rock), red sphere (berry bush), green
strand (fiber), dark grey vein (ore), purple crystal (crystal cluster). <500 tris each.

**Instance positioning:** Each resource gets a slight random offset within its hex tile
(not dead-center) for visual variety. Offset = ±15% of hex radius (i.e., ±`HEX_SIZE × 0.15`
= ±0.45 world units at HEX_SIZE=3.0). Computed deterministically from coords +
resource index (seeded, not truly random — consistent across save/load).

**Mesh variants:** Full → depleted (tree → stump, rock → rubble). Swap via instance
custom data channel (shader reads a flag) or by maintaining two MultiMesh pools per
type (full + depleted) and moving instances between them.

**Fog-aware:** Resources on HIDDEN tiles not instanced. REVEALED tiles dimmed via
custom data (same pattern as hex tiles). VISIBLE = full.

---

### Mobile Specs

#### Performance — Auto-Interaction Processing

| Operation | Cost | When |
|-----------|------|------|
| Proximity check (auto-gather) | O(7): current tile + 6 neighbors × 1-3 resources each = max 21 checks. Each: catalog lookup (hash O(1)) + tool check (O(1)) | On tile_entered (each player move) |
| Auto-defend check | O(n): n = active fauna (1-3 in MVP). Distance + catalog + hostile check per fauna | On tile_entered + on fauna_moved |
| Auto-pickup | O(m): m = ground items on tile (typically 0-3) | On tile_entered |
| Respawn queue tick | O(q): q = depleted resources (50-100 max) | Every frame |
| Gather tween | One float per frame (Tween internal) | During active auto-gather only |

**No per-frame cost when not gathering.** The main cost is the proximity check on
`tile_entered` — 18 checks with hash lookups. Negligible (<0.1ms).

#### Draw Call Budget — Auto-Interaction Share

| Renderer | Draw Calls | Notes |
|----------|-----------|-------|
| ResourceRenderer | ~6 | One MultiMesh per resource type |
| **Total** | **~6** | Within budget (terrain ~5, icons ~6, resources ~6 = ~17 total) |

#### Gather Timing

Auto-gather starts immediately on `tile_entered` — no delay beyond the gather_time
tween. The player experiences:

1. Walk onto tile → 0ms delay
2. Auto-gather starts on adjacent resource → gather_time (0.5s–2.5s depending on type + tool)
3. Tween completes → "+1 Wood" feedback
4. Immediately chains to next resource if available

**Latency from movement to first gather:** <16ms (one frame). The `tile_entered` signal
fires synchronously during the tile transition sequence. AutoInteractionSystem receives
it in the same frame.

**Fly-to-player visual:** On gather complete, resource sprite tweens from resource
world position to Player.position over ~0.5s (tunable, should scale with fly distance).
**[TUNING_REQUIRED]** — at HEX_SIZE=3.0 adjacent resource is ~3 world units away; 0.3s
would appear 3× faster than intended. This is a lightweight Tween on a temporary
Sprite3D (or screen-space label). One active at a time during chain gathering.
No draw call impact — sprite exists briefly then `queue_free`.

#### Touch Interaction

None. Auto-interaction has zero touch input. All triggers are `tile_entered` (player
movement) and `fauna_moved` (creature AI). The player controls where to walk —
feature-002 owns all touch input.

#### Platform Differences

None. Pure GDScript logic + Godot signals. iOS and Android identical.

#### Memory

- ResourceRenderer: 6 MultiMesh pools × ~50 instances = ~300 instances. ~64 bytes each. <20KB.
- Respawn queue: ~100 entries × ~32 bytes = ~3KB.
- AutoInteractionSystem state: negligible (booleans, Vector2i, float).
