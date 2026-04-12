# LightingManager
**Source:** `scripts/lighting/lighting_manager.gd`
**Category:** genre-specific
**Layer:** autoload
**Depends on:** [`prop_registry.md`](prop_registry.md), [`hex_grid.md`](hex_grid.md), [`day_night_cycle.md`](day_night_cycle.md), [`light_cap.md`](light_cap.md)

## What this system is

LightingManager tracks every active light source in the world and exposes them as a flat
array to the hex terrain shader so it can render local puddles of light at night. There are
two kinds of lights: **structure lights** (placed props that carry a LightCap — campfires,
torches, lanterns) and a single **player-carried torch** (equipped tool with a LightCap).
The manager keeps both kinds in sync with gameplay events — structures appear on
`structure_placed`, disappear on `structure_destroyed`, the player torch follows
`tile_entered` and tool equipment changes — and returns an empty array during DAY and DAWN
phases so the sun overrides local lights for free. It is the fourth autoload in
`project.godot`, running after DayNightCycle so its day-phase check can find the clock.

## Promises to content

- **`get_active_lights()` is the shader feed.** Returns an
  `Array[Dictionary]` with entries `{position: Vector2, radius: float, color: Color}`.
  During DAY and DAWN phases it returns an empty array unconditionally — callers don't need
  to gate by time. Positions are in world-space XZ (matching HexGrid's `axial_to_world`
  output). Radii are in world units (sub-hex ring × `RING_TO_WORLD = 3.0`).
- **Structure lights register automatically.** When `HexGrid.structure_placed` fires, the
  manager looks up the placed prop's `LightCap` via PropRegistry and, if present, adds an
  entry keyed on `"coords:type:sub_hex"`. No manual registration needed — authoring a light
  source means adding a `LightCap` to the PropDef and placing it through the normal
  building flow.
- **Structure lights unregister on destroy.** `HexGrid.structure_destroyed` removes every
  entry whose key starts with `"coords:type:"`, covering all sub-hex positions for that
  (tile, type) pair.
- **`scan_existing_lights()` rebuilds the structure table from scratch.** Called after a map
  load or save load (which do not re-emit `structure_placed`), it walks every tile, finds
  every prop with a LightCap, and re-indexes them. Clearing and rescanning is the correct
  way to bring the manager in sync with HexGrid after a cold load.
- **Player torch tracking is inventory-driven.** `update_player_torch()` walks the player's
  tool slots (`axe`, `pickaxe`, `weapon`, `scanner`, `firestarter`), finds the first equipped
  tool whose PropDef has a LightCap, and either installs or clears the torch entry. Callers
  invoke it on tool equipment changes.
- **Torch position follows the player tile.** The `tile_entered` handler updates the cached
  player world position and, if a torch is active, rewrites its `position` field and emits
  `light_source_moved`.
- **`is_night_active()` is a cheap boolean for other systems.** Returns `true` during DUSK
  and NIGHT. Useful for systems that want to turn on night-only behavior without duplicating
  the phase check.
- **Signals narrate the table.** `light_source_registered(position, radius)`,
  `light_source_unregistered(position)`, and `light_source_moved(position)` fire on every
  mutation. Debug visualisers subscribe to these; gameplay systems usually don't need to.
- **Injectable dependencies for tests.** `_grid`, `_dnc`, and `_registry` default to the real
  autoloads but can be replaced in tests before `_ready` runs. `initialize_player_torch(player)`
  exists as a direct-reference seam for startup flows where the `player` group isn't populated
  yet.

## Requirements from content

- **Lights are LightCap on PropDef.** A placeable prop that should emit light must carry a
  `LightCap` sub-resource with `radius` (in sub-hex rings) and `color`. See
  [`light_cap.md`](light_cap.md) for the cap's own contract. A prop without LightCap is
  simply not tracked.
- **Player torches are tool-slot PropDefs with LightCap.** The player inventory's tool slots
  are scanned in the fixed order `[axe, pickaxe, weapon, scanner, firestarter]` and the
  first tool with a light cap wins. If a player holds multiple torches in different slots,
  only the first slot-order match lights up.
- **`tool_slot`** on the PropDef determines which slot the tool occupies — the manager reads
  the tool by slot name via `inv.get_tool(slot)`, not by any light-specific field.
- **Shader cap on simultaneous lights.** `MAX_LIGHTS = 8` is the constant the shader expects.
  The manager does not currently clip the array to this length on its own — callers that
  forward to the shader must slice the first 8 entries. Future work: move the slicing here.
- **Shader radius unit.** `RING_TO_WORLD = 3.0` is the multiplier that converts
  "sub-hex rings" (LightCap's `radius`) to world units. Mods that edit `HEX_SIZE` must edit
  this too to keep light extents visually correct.
- **Zero-radius lights default to 3 rings.** If `LightCap.radius` is zero, the manager
  substitutes `3.0 * RING_TO_WORLD`. Authoring intent: "I forgot to set a radius" maps to
  a sensible fallback instead of invisible lights.
- **Default color fallback.** If `LightCap.color` is `Color()` (the zero color, which is
  black-ish), the manager substitutes `DEFAULT_LIGHT_COLOR` — a warm orange fire glow.
  Authoring black lights is not supported.

## Extension points

- **Direct `register_light(key, ...)` / `unregister_light(key)`.** For dynamic lights that
  aren't placed structures — explosions, spell effects, debug overlays. Callers pick a key
  string; convention is `"type:id"`. Player torches go through `set_player_light` /
  `clear_player_light` for consistency with the tracking path.
- **Mock registries in tests.** Replace `_grid`, `_dnc`, or `_registry` with stubs before
  the tree adds the autoload; the `_ready` block honors non-null overrides. See
  `tests/unit/test_lighting_manager.gd`-style scaffolding.
- **Custom torch policy.** `update_player_torch` walks a hard-coded slot list. A game with a
  different tool slot taxonomy must either patch the slot array or call
  `set_player_light` directly from its own inventory listener.
- **Shader uniform feed.** Whatever system forwards lights to the terrain shader (today, the
  main scene's rendering driver) is the consumer of `get_active_lights`. A different
  renderer pipeline would replace that consumer without touching LightingManager.

## Genre-specific notes

LightingManager is **mostly engine-general** as a registry: "track N light sources, expose
them to a shader, mute during day." The shape transfers to any game with a day/night cycle
and placed lights.

The **Farhaven-specific edges** are:

- **Sub-hex ring units.** `RING_TO_WORLD` assumes a hex map and computes radius in hex-aware
  units. A square-grid game would compute radius in tile widths instead.
- **Tool slot names.** The hard-coded `[axe, pickaxe, weapon, scanner, firestarter]` slot
  list is explicitly Farhaven's tool taxonomy. A second game would edit that list.
- **Day/dawn override.** Choosing "no local lights during DAY or DAWN" is a Farhaven
  palette choice (day is bright enough; dawn transitions from black to bright so local
  lights would fight the tween). A game with mid-day caves would disable this gate.
- **8-light shader cap.** Tied to the terrain shader's uniform array size, not to the
  manager. A different rendering back-end would want a different cap.
- **Orange default color.** Farhaven's default light source is "fire," so the fallback
  color is warm orange. Sci-fi or fantasy games might pick different defaults.

## Known limitations and TODOs

- **No clipping to `MAX_LIGHTS` in the manager.** If more than 8 lights are active at once,
  the consumer must slice the array. The correct fix is to rank lights by proximity to the
  player and return only the top 8; deferred to task-088.
- **Player torch is single-slot.** Only the first matching tool wins. If content wants
  "two lanterns double the radius," that logic must live elsewhere.
- **Structure light keys include sub_hex but destroy matches on coords+type only.** That
  means destroying one of two same-type props on the same tile removes both. This is
  intentional in practice (only one lantern per tile today) but will need sub-hex-aware
  destruction if multi-prop tiles become common. Track in task-088.
- **No color interpolation with day/night phase.** Structure lights stay orange through
  DUSK and NIGHT; they don't warm up or cool down with the phase. Dusk/night transitions
  look slightly abrupt with large numbers of lights.
- **`update_player_torch` iterates tool slots linearly.** Cheap for 5 slots, but if the
  inventory API changes to expose "all equipped tools with lights" the iteration should
  move there.
- **Headless / test guards are defensive but not exhaustive.** `_find_player` returns null
  when the tree is absent; the caller clears the torch. Tests that run the manager in
  isolation must either inject `_grid` / `_registry` or accept that lights stay empty.
