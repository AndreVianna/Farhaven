# SpawnableCap

**Source:** `scripts/data/capabilities/spawnable_cap.gd`
**Category:** core
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`fauna_manager.md`](fauna_manager.md), [`day_night_cycle.md`](day_night_cycle.md), [`hex_grid.md`](hex_grid.md)

## What this system is

SpawnableCap tells a spawn subsystem — FaunaManager in delivery-006d, potentially other
world-generation systems in the future — how a PropDef should enter the world without
player action. It answers five questions: how many at once (`spawn_min` / `spawn_max`),
starting from which in-game day (`first_spawn_day`), how far from the player
(`spawn_min_distance`), and in which biomes (`allowed_biomes`). The cap is used almost
exclusively for fauna today (wolves, rabbits, deer), but the shape is general enough to
drive resource-node spawning (ore veins, berry bushes), weather spawns, or any other
"world fills itself" mechanic.

## Promises to content

- **SpawnableCap is opt-in via PropDef.** A PropDef without a `spawnable` cap is not
  spawned by any automated system. Adding the cap makes the prop eligible for the
  FaunaManager spawn loop (for creatures, alongside BehaviorCap + EnduranceCap + MovementCap).
- **`spawn_min` and `spawn_max` define the group size range.** FaunaManager picks a count
  via `randi_range(spawn_min, spawn_max)` and spawns that many at once. Both fields
  default to `1`, producing single spawns. Setting `spawn_min = 2` and `spawn_max = 5`
  produces groups of 2-5, appropriate for a pack or herd creature.
- **`first_spawn_day` is a progression gate.** FaunaManager checks
  `DayNightCycle.day_count < def.spawnable.first_spawn_day` before each spawn attempt
  and suppresses the spawn if the day has not been reached. This is how "wolves only
  appear after day 4" is authored: set `first_spawn_day = 4` on the wolf PropDef.
- **`spawn_min_distance` is the player-safety radius, measured in hex tiles.** Spawns
  inside the radius are rejected — the spawn loop looks for candidate tiles at least
  `spawn_min_distance` away from the player's current position. A value of `3` (the
  default) means "do not spawn within 3 hex rings of the player."
- **`allowed_biomes` is a biome tag allowlist.** If the array is non-empty, the spawn
  loop restricts candidate tiles to ones whose biome is in the list. An empty array
  means "any biome" — no restriction.
- **Interaction with group behavior.** `BehaviorCap.group_behavior` shapes how the count
  is used: a `SOLO` creature is forced to count 1 regardless of `spawn_max`; a `PAIR`
  creature prefers 2; larger groups come from `PACK`/`HERD`/`SWARM`. SpawnableCap
  provides the numeric envelope; BehaviorCap shapes the distribution within it.
- **SpawnableCap is shared across instances.** Every wolf shares one SpawnableCap.
  Per-instance state (spawn timestamp, spawn position) lives on the spawned node and
  in the FaunaManager's internal tracking.

## Requirements from content

- **Sub-resource shape, not dictionary.** SpawnableCap must be authored as an inline
  `[sub_resource type="Resource"]` block with `script = ExtResource("spawnable_cap")`.
- **`spawn_min` ≤ `spawn_max`.** Violating this produces undefined behavior from
  `randi_range`. Both are `int`, defaulting to `1`.
- **`first_spawn_day` is a `int` with the convention `1 = from the start`.** The default
  is `1`, meaning no gate beyond day 1. Setting `0` or a negative value is meaningless;
  setting `1` is effectively "any time."
- **`spawn_min_distance` is an `int` in hex tiles, not sub-hex.** This is a coarse
  "do not spawn in the player's face" radius — fine precision is not needed.
- **`allowed_biomes` entries are `StringName`, not `String`.** Using plain strings
  silently fails every match.
- **Biome tags must match what the map layer emits.** A typo or a new biome name will
  silently restrict the cap to zero eligible tiles. Content should keep the biome
  vocabulary in sync with the map/hex-tile contract.
- **For fauna, the cap alone is not enough.** FaunaManager's spawn eligibility check
  requires `spawnable` **and** `behavior` **and** `endurance` **and** `movement`. A
  PropDef with only `spawnable` will not spawn as a creature — it might still spawn as
  a resource node if a future non-fauna spawn system consumes the cap.

## Extension points

- **Time-of-day spawn gating.** Adding a `spawn_phases: Array[StringName]` field would
  let authors say "this creature only spawns at night." Currently the day/night
  integration lives on BehaviorCap's `activity_cycle` — spawned creatures exist but
  hide during off-phases — rather than on SpawnableCap. A future split is reasonable.
- **Max population cap.** A field like `max_population: int = -1` would let authors cap
  the total number of a given creature type in the world at any time. Currently the
  soft cap lives in FaunaManager's spawn budget, not on the cap.
- **Despawn rules.** "If the player is > 50 tiles away, despawn" is not on SpawnableCap;
  it is FaunaManager's call. Adding a `despawn_distance` field could centralise the
  policy on the data side.
- **Alternative spawn systems.** A future weather system, resource regen system, or
  catastrophic-event system could all consume SpawnableCap with different interpretations
  of the fields. The cap shape is general enough to support these without change;
  new systems would add their own eligibility checks (e.g. "spawn during a storm").
- **Biome-specific counts.** "Spawns in forests in groups of 2-5, spawns in grasslands
  in groups of 1-2" is not expressible. The fields are global across biomes.

## Genre-specific notes

SpawnableCap is **mostly genre-agnostic.** The shape — count range, gate day, player
safety radius, biome allowlist — describes a "something enters the world under these
rules" contract that any game with procedural or scheduled world-population would use.

- **Generic parts.** The count range and the allowlist concept transfer across genres.
  A Civ-like second game could use `spawn_min`/`spawn_max` for barbarian camp sizes and
  `allowed_biomes` for terrain restrictions. A Catan-like game could reinterpret the
  fields as "how many robbers appear per draw event."
- **Farhaven-specific parts — hex grid and day count.** `spawn_min_distance` is measured
  in hex tiles, which is a hex-grid assumption. `first_spawn_day` assumes an integer
  day counter driven by DayNightCycle, which is a real-time-cycle assumption. A game
  without day/night would either leave `first_spawn_day` at its default or reinterpret
  it as "turn number" / "era index."
- **Biome-tag convention.** `&"FOREST"`, `&"GRASSLAND"`, etc. are Farhaven biome names.
  Tags are free-form `StringName`, so a second game can swap the vocabulary freely.
- **"Fauna + SpawnableCap" coupling is a Farhaven convention.** SpawnableCap is
  currently consumed only by FaunaManager. A second game that had resource-node
  spawning or loot-drop spawning would write its own consumer and share the cap.

The pragmatic framing: SpawnableCap is a utility cap. It sits near the Farhaven-specific
end of the spectrum because its current consumer (FaunaManager) is survival-genre
flavored, but the cap's shape is portable.

## Known limitations and TODOs

- **One consumer only.** In delivery-006d, only FaunaManager reads SpawnableCap. A
  resource-node spawn system or weather system that wanted to reuse the cap would
  need to add its own eligibility check and its own spawn loop. The cap is forward-
  compatible with that, but today the runtime coupling is 1:1 with fauna.
- **No density / distribution hint.** SpawnableCap says "1-5 at a time" but says nothing
  about "globally rare" vs "globally common." FaunaManager currently treats every
  spawnable creature as equally likely to be selected for a spawn attempt. A
  `spawn_weight: float = 1.0` field is a reasonable future addition.
- **No max-alive cap.** Content authors cannot express "never more than 10 wolves in
  the world." This cap lives (implicitly) in FaunaManager's spawn budget; moving it
  onto the data side would be cleaner.
- **No despawn semantics.** SpawnableCap describes when to spawn, not when to despawn.
  Distance-based despawn, day-count despawn, and hunger-based despawn all live
  elsewhere (or do not yet exist).
- **Biome tags uncoordinated.** There is no central biome-tag registry; typos produce
  silent spawn failures. A future validator could cross-check biome tags against the
  map layer's known biomes.
- **`first_spawn_day = 1` is the "no gate" convention, not `0`.** Slightly surprising
  — authors who want "spawn from the start" expect `0` and sometimes get a confusing
  one-day delay. Consider explicit documentation at authoring time.
