# FaunaManager

**Source:** `scripts/fauna/fauna_manager.gd`
**Category:** genre-specific
**Layer:** system
**Depends on:** [`prop_def.md`](prop_def.md), [`spawnable_cap.md`](spawnable_cap.md), [`behavior_cap.md`](behavior_cap.md), [`movement_cap.md`](movement_cap.md), [`endurance_cap.md`](endurance_cap.md), [`hex_grid.md`](hex_grid.md), [`hex_tile.md`](hex_tile.md), [`day_night_cycle.md`](day_night_cycle.md), [`lighting_manager.md`](lighting_manager.md), [`prop_registry.md`](prop_registry.md). Not an autoload — child Node of Player.

## What this system is

FaunaManager is Farhaven's **night-time creature simulation**. It runs the spawn, pathfinding,
contact-damage, and despawn lifecycle for every hostile creature that appears during the
night phase of the day/night cycle. Each fauna entry is a `Dictionary` (not a Node in the
scene tree), kept in an array owned by the manager. This keeps creatures cheap — no scene
churn, no physics, no nodes — and keeps their behaviour fully deterministic for testing.

Species-specific data (HP, movement speed, elevation jump, detection range, spawn constraints)
is read from the species' PropDef through four capabilities: `EnduranceCap`, `MovementCap`,
`BehaviorCap`, `SpawnableCap`. A species without all four caps is skipped with a warning.

## Promises to content

- **Spawning happens at night, after the first-spawn day is reached.** On every
  `DayNightCycle.night` signal, FaunaManager iterates its `CHAPTER1_SPECIES` list and, for
  each species whose `spawnable.first_spawn_day` has been reached, spawns between
  `spawnable.spawn_min` and `spawnable.spawn_max` instances on candidate tiles.
- **Spawn candidates must be passable, non-water, non-structure, outside player spawn distance,
  and unlit.** The four filters together define where fauna can appear. Lit tiles (covered by
  a `LightCap` radius currently active via LightingManager) are explicitly excluded, so
  players can use fire to carve out safe zones.
- **Minimum distance from the player.** `spawnable.spawn_min_distance` is a floor on the hex
  distance between the spawn tile and the player's current tile. Content can tune this per
  species.
- **Movement ticks on each fauna's own cooldown.** Each creature has a `cooldown_remaining`
  that counts down per frame. When it hits zero, the creature picks a best neighbour tile
  (closer to player, passable, unlit, not occupied by another fauna) and moves there. Cooldown
  is derived from `MovementCap.modes` (`WALK` mode normal speed if present, otherwise the
  lowest-numbered mode's normal speed).
- **Detection range gates movement.** A fauna more than `BehaviorCap.detection_range` hexes
  from the player stops moving. Creatures with no behavior cap fall back to range 0 (inert).
- **Elevation jump uses MovementCap.JUMP mode.** If the species has `JUMP` mode in its
  `MovementCap.modes`, the first value of the speed array becomes the max elevation difference
  the fauna can traverse. Otherwise default is 1 (one elevation step).
- **Contact damage is applied on adjacency.** Any fauna whose movement tick put it within
  hex distance 1 of the player (including same-tile) emits
  `fauna_attacked_player(id, damage, species_type)`. Damage is `DEFAULT_CONTACT_DAMAGE` (10)
  until the combat runtime lands; shelter (a tile prop with a `StationCap` carrying the
  `&"respawn"` station tag) clamps damage to zero.
- **Surprise encounters fire when a creature outside light becomes adjacent to the player.**
  `fauna_surprise_encounter` fires on the frame the adjacency check first passes, letting
  ScannerSystem register an ENCOUNTERED state in the catalog.
- **Despawn at dawn.** On `DayNightCycle.dawn`, every living fauna emits `fauna_despawned`
  and is removed from the internal array. No state persists across day/night boundaries.
- **Damage kills, death places a corpse.** `apply_damage(fauna_id, damage)` is the public
  hook for outside attackers (auto-defend, future combat). If HP drops to zero, a corpse
  Prop is placed on the fauna's tile and `fauna_killed` fires.
- **Fauna are identified by integer ids, not by Node references.** IDs are monotonic and
  never reused. Any system that wants "the fauna at id 42" calls `get_fauna_at(coords)` or
  walks `get_all_fauna()`.

## Requirements from content

- **Must be child of Player.** Like sibling systems, FaunaManager walks `get_parent()` to
  find the player and reads `player.current_tile`.
- **Species must be registered in CHAPTER1_SPECIES.** The array is a constant compile-time
  list of species PropDef ids. Adding a new chapter or a new species requires editing this
  constant (or providing a more general mechanism — flagged below).
- **Species PropDef must have four capabilities.** `endurance`, `movement`, `behavior`, and
  `spawnable` must all be non-null or the spawn is skipped with a warning. Each cap is read
  at spawn time — content can tune HP, speed, detection range by editing the cap values in
  the `.tres` file.
- **PropRegistry, HexGrid, DayNightCycle, LightingManager must be registered as autoloads.**
  `_ready` resolves all four; tests can inject via the matching `_grid`, `_dnc`, `_lighting`,
  `_registry` fields.
- **Tiles with blocking props are untraversable.** The fauna passability check looks for any
  prop with tag `&"BLOCKS_MOVEMENT"`. Content that wants a creature to tunnel through things
  would need a different passability rule.
- **Shelter detection uses `StationCap.station_tags.has(&"respawn")`.** Any structure with a
  station cap tagged `&"respawn"` counts as shelter. Content that wants non-respawn shelter
  needs a different tag rule.

## Extension points

- **Inject dependencies for tests.** All four autoload references (`_grid`, `_dnc`,
  `_lighting`, `_registry`) are public-ish fields that tests override before `_ready`. The
  pure Dictionary-based fauna model means tests can set up creature state directly without
  instantiating scenes.
- **Signals are the integration surface.** `fauna_spawned`, `fauna_moved`, `fauna_attacked_player`,
  `fauna_killed`, `fauna_despawned`, `fauna_surprise_encounter` are the public subscription
  points. FaunaRenderer reads these to draw creatures; ScannerSystem reads `fauna_attacked_player`
  for first-encounter cataloguing; AutoInteractionSystem reads `fauna_moved` for auto-defend.
- **`get_fauna_at`, `get_fauna_adjacent_to`, `get_all_fauna`.** Read-only query API that
  returns duplicated dictionaries (safe to mutate the returned copy).
- **`is_hostile(id)` and `get_fauna_entry_id(id)`.** Called by AutoInteractionSystem's
  auto-defend path. Currently returns hardcoded values tied to P00108 but intended to
  become data-driven (see limitations).

## Genre-specific notes

FaunaManager is **highly genre-specific** — it encodes a particular survival / horror
posture.

- **Night-only spawning.** The "only at night, despawn at dawn" cycle is classic survival
  horror (The Long Dark, 7 Days to Die). A game with permanent fauna would remove the
  day/night gating entirely.
- **Light-as-repellent.** Spawns avoid lit tiles; moves avoid lit tiles. This is a deliberate
  mechanical reward for building fires. A different genre (zombie survival, military shooter)
  would use different repellents — sound, cover, factions.
- **No pathfinding, just greedy best-neighbour.** The AI moves one step at a time toward the
  player, choosing the neighbour with the shortest hex distance. There's no A* and no
  global path planning. This works because Farhaven fauna are stupid creatures on a small
  map. A strategic game with thinking enemies needs a proper pathfinder.
- **Contact damage is a placeholder.** The `DEFAULT_CONTACT_DAMAGE` constant is a stopgap
  until attack events exist. The combat runtime (delivery-006d task-088) will replace this
  with real attack/defense resolution via `CombatCap`.
- **Dictionary-based model is genre-agnostic.** The "creatures as rows in a table, not as
  scene nodes" pattern is great for performance and testability. It transfers cleanly to
  any game that needs many cheap creatures: strategy, roguelike, MMO background mobs.
- **Surprise encounter is horror-flavoured.** The signal exists specifically to wire up a
  "first sighting → catalog entry" horror beat. A different genre might use the same signal
  for "aggro pings" or "spotted by enemy" notifications.

## Known limitations and TODOs

- **CHAPTER1_SPECIES is a hardcoded constant.** Adding a new species requires a code edit.
  A future pass will read the species list from PropRegistry by filtering on the
  `SpawnableCap` presence — but this needs cap-level metadata to distinguish "hostile fauna"
  from other spawnables (flowers, ambient wildlife).
- **Corpse prop type is hardcoded per species.** `_get_corpse_type` has a literal match on
  `&"P00108" → &"P00107"`. Long term this should be a field on SpawnableCap or BehaviorCap
  (`corpse_def`). Flagged.
- **is_hostile / get_fauna_entry_id are stubs.** AutoInteractionSystem calls these methods
  on FaunaManager for auto-defend resolution, but the current v1 implementation returns
  hardcoded values. They need proper BehaviorCap-driven resolution.
- **No inter-fauna interaction.** Fauna avoid stacking on the same tile (via `_is_fauna_at`)
  but do not coordinate, herd, flock, or flee from each other. Flocking behaviour would
  extend BehaviorCap and the movement loop.
- **No saved state across day/night.** Creatures are fully transient: spawn at night, die or
  despawn at dawn, no memory. This is a design choice for v1 but limits narrative possibilities
  ("the same wolf is back" is impossible without persistent ids across cycles).
- **Combat runtime missing.** Attack/defense resolution via `CombatCap` isn't wired up yet.
  Until it lands, fauna-versus-player damage is the hardcoded 10 and player-versus-fauna
  damage comes from AutoInteractionSystem's WEAPON_DAMAGE table.
- **Spawn tile selection is O(n) over all tiles.** For a 200–300 tile map this is fine, but
  a larger map would want a spatial index.
