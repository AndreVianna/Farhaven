# MovementCap

**Source:** `scripts/data/capabilities/movement_cap.gd`
**Category:** genre-specific
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`fauna_manager.md`](fauna_manager.md), [`hex_grid.md`](hex_grid.md)

## What this system is

MovementCap is the locomotion block for anything that moves under its own power on the
hex grid. When a PropDef represents a creature, attaching a MovementCap tells the fauna
subsystem which movement modes the creature can use (walk, swim, fly, burrow, climb, jump)
and how fast it goes in each mode, in **sub-hex-per-second** units tied directly to
Farhaven's HexGrid spatial vocabulary. The shape is a single `Dictionary` keyed by the
`Mode` enum, with values that are `[normal_speed, max_speed]` pairs. Derived quantities
like `move_cooldown` (seconds per sub-hex) and `max_jump` (elevation delta for the JUMP
mode) are computed by FaunaManager from this dictionary — MovementCap itself is
pure data.

**⚠️ Note carefully: MovementCap is not MovableCap.** MovementCap describes how a creature
walks/swims/flies across the map. MovableCap is a world-level "can this placed prop be
shoved" marker. The two share a prefix but serve completely different roles.

## Promises to content

- **MovementCap is opt-in via PropDef.** A PropDef without a `movement` cap is immobile.
  Attaching a MovementCap via PropDef's `movement` slot is how a creature declares it can
  move. FaunaManager requires MovementCap (plus `behavior`, `endurance`, and `spawnable`)
  before it will treat the PropDef as tickable fauna.
- **`modes` is a `Dictionary` keyed by Mode enum, valued by `[normal, max]` float pairs.**
  `{0: [1.0, 1.5]}` means "WALK mode at 1 sub-hex/s normal, 1.5 sub-hex/s max." Multiple
  entries mean multiple available locomotion modes — an amphibian is `{0: [1.0, 1.5],
  1: [0.8, 1.2]}` (walk and swim), a bird is `{2: [3.0, 5.0]}` (fly), a frog is
  `{0: [1.0, 1.5], 5: [2.0, 3.0]}` (walk and jump). An empty dictionary means "no modes
  available" and is effectively identical to "no MovementCap at all" from FaunaManager's
  point of view.
- **Speeds are measured in sub-hex per second.** A "sub-hex" is Farhaven's subdivision of
  a hex tile — HexGrid exposes the subdivision factor. The unit is deliberately chosen so
  that small creatures and large creatures can share the same number line (a wolf at 2.0
  sub-hex/s and a crab at 0.5 sub-hex/s are directly comparable) and so the derivation
  `move_cooldown = 1.0 / normal_speed` yields seconds-per-sub-hex, which is what the
  real-time loop wants.
- **`move_cooldown` is derived, not stored.** FaunaManager computes it from the normal
  speed of the creature's primary mode. There is no per-mode cooldown field; the formula
  is `seconds-per-sub-hex = 1.0 / normal_speed`.
- **`max_jump` is derived from the JUMP mode entry.** If the creature has a JUMP mode
  (key `5`), FaunaManager uses `modes[5][0]` (the normal value) as the elevation delta
  the creature can jump in hex elevation levels. If there is no JUMP entry, the default
  elevation delta is `1` (single-step climb). The derivation is deliberate: the JUMP
  mode's "speed" number is reused as "jump height" so that content authors can express
  it without a second field.
- **The `Mode` enum is closed.** Current values: `WALK=0`, `SWIM=1`, `FLY=2`, `BURROW=3`,
  `CLIMB=4`, `JUMP=5`. Adding a new mode requires editing the enum in `movement_cap.gd`
  and the derivation logic in FaunaManager. This is by design — modes are small and
  enumerable.
- **MovementCap is shared across instances.** Every wolf shares one MovementCap. The
  creature's current position, heading, and cooldown-remainder all live on the spawned
  node.

## Requirements from content

- **Sub-resource shape, not dictionary of dictionaries.** MovementCap itself must be
  authored as a `[sub_resource type="Resource"]` block with
  `script = ExtResource("movement_cap")`. The `modes` field *inside* the cap is a normal
  Godot Dictionary — integer keys mapping to 2-element float arrays.
- **Mode keys are the `Mode` enum integer values, not strings.** Use `0` for WALK, `1`
  for SWIM, `2` for FLY, `3` for BURROW, `4` for CLIMB, `5` for JUMP. Authoring tools
  should surface the enum by name but serialise the integer.
- **Each value is exactly a 2-element `Array[float]` of `[normal, max]`.** Shorter or
  longer arrays are authoring errors. Using the same value twice (e.g. `[1.0, 1.0]`) is
  valid and means "no sprint."
- **Speeds must be positive.** Zero or negative normal speed breaks the
  `move_cooldown = 1.0 / normal_speed` derivation (divide-by-zero or nonsense values).
  A creature that cannot move in a given mode should simply not list the mode.
- **A creature that jumps AND walks must have both entries.** `{5: [2.0, 3.0]}` alone
  gives a creature that can only jump, which is probably not what the author wants. The
  canonical "frog" is `{0: [1.0, 1.5], 5: [2.0, 3.0]}`.
- **Do not encode directional anisotropy.** The cap assumes speed is isotropic per mode —
  walking north is the same speed as walking east. Direction-dependent speed would need
  a different schema.

## Extension points

- **Adding a new mode.** Edit the `Mode` enum in `movement_cap.gd`, then update
  FaunaManager's derivation logic if the new mode needs special handling (like the
  JUMP reuse for elevation). Existing PropDefs remain valid because the `modes`
  dictionary is open — any unused key is simply ignored by content that does not carry it.
- **Per-mode cooldowns.** The current derivation uses the primary mode's normal speed for
  the single `move_cooldown`. If a creature with distinct walk/swim cooldowns is needed,
  FaunaManager can be extended to pick the cooldown based on the active mode without
  changing the cap shape.
- **Terrain-gated modes.** The cap says "this creature can fly." Whether it *should* fly
  over a specific hex is up to FaunaManager and HexGrid's movement cost logic. MovementCap
  does not encode "cannot swim in lava" or "can only burrow in sand" — those predicates
  live on the map side.
- **Speed modifiers.** A creature that slows down at night, speeds up when aggroed, or
  slows when carrying cargo would layer those modifiers on the spawned node's active
  speed, not on MovementCap. The cap is the base rate.

## Genre-specific notes

MovementCap is **Farhaven-specific — hex grid, real-time.** This is one of the most
genre-entangled caps in the engine, in two independent dimensions:

- **Hex grid assumption.** The `sub-hex per second` unit only makes sense on a hex grid
  with HexGrid's subdivision model. A game on a square grid would have "tiles per second"
  or "subcells per second" and would need to reinterpret the field. A continuous-plane
  game would have "units per second." Neither is catastrophically different — the field
  is a plain float — but the spatial vocabulary is Farhaven's.
- **Real-time assumption.** The `move_cooldown = 1.0 / normal_speed` derivation produces
  seconds-per-step, which assumes the fauna loop runs on a real-time `_process` tick. A
  turn-based game would either reinterpret the field as "steps per turn" (integer-like)
  or layer a TurnManager on top to convert seconds into turn-friendly action costs. This
  is flagged as future engine-v2 scope in **delivery-006d task-088**.

Beyond those two axes, the shape is otherwise reusable:

- **The `Mode` enum vocabulary** (walk/swim/fly/burrow/climb/jump) is ecology-game
  flavored but broad. A strategy game with "ground, naval, air" unit classes could reuse
  three of the six modes unchanged.
- **The normal/max split** (sprint mode) is a generic idea — most games with per-unit
  speeds want a baseline and a burst. The cap's shape supports it directly.

Engine v2 reuse for another hex-grid real-time ecology game is direct. Reuse for a
square-grid or turn-based game requires the reinterpretation flags above; the cap itself
does not need to change, but the documentation, the units, and the consumer code do.

## Known limitations and TODOs

- **🚨 Sub-hex unit is not self-describing.** The cap stores numbers; the meaning
  ("sub-hex per second") lives in a comment and in FaunaManager. A new engineer reading
  the cap alone will not know what `1.5` means. A future cleanup could add a unit
  annotation or a factory method.
- **🚨 Mode keys are raw integers.** On disk, `modes` looks like `{0: [1.0, 1.5]}` —
  there is no hint that `0` means WALK. Authoring tools should expose the enum by name,
  but raw `.tres` editing is error-prone.
- **JUMP mode overloading is a hack.** Reusing the speed number as elevation-delta is
  convenient but fragile. A content author who tweaks jump *speed* will silently change
  jump *height*. A future refactor could split the two into separate fields.
- **No `max_jump` field.** Elevation-delta is derived from JUMP mode, not stored. A
  non-jumping creature that should still be able to climb one hex of elevation relies on
  a hardcoded default (1) in FaunaManager.
- **No climb/burrow ruleset.** CLIMB and BURROW modes are enumerated but the consumer
  (FaunaManager) does not currently differentiate them from WALK in its movement
  pipeline. Content can author them today as a forward-looking signal; runtime hookup is
  pending.
- **Real-time assumption bakes in `_process`-tick loops.** A turn-based refactor would
  need to introduce a TurnManager layer that converts `seconds-per-sub-hex` into
  `action-points-per-move`, or the cap would need a parallel "turn mode" field. Flagged
  for engine-v2.
- **No stamina or fatigue coupling.** A creature that slows when tired is not expressible
  on this cap. That coupling would live between MovementCap (base rate) and a future
  EnergyCap or on the spawned node's runtime state.
