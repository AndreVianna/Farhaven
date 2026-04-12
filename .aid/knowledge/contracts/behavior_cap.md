# BehaviorCap

**Source:** `scripts/data/capabilities/behavior_cap.gd`
**Category:** genre-specific
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`fauna_manager.md`](fauna_manager.md), [`event_registry.md`](event_registry.md)

## What this system is

BehaviorCap is the AI policy block for creatures. When a PropDef represents live fauna — a
wolf, a rabbit, a deer — attaching a BehaviorCap tells the FaunaManager how that creature
perceives the world, when it is active, how it groups with its kind, what it eats, and how
it reacts to non-combat stimuli. BehaviorCap is not a combat script (CombatCap handles
attacks/defenses) and it is not a movement script (MovementCap handles speeds and locomotion
modes). It is the "personality and policy" slot: detection range, activity cycle, group
topology, diet tags, and an event-list for reactions like fleeing, calling for help, or
pausing to graze. FaunaManager reads these fields at spawn time and each tick to decide
what the creature should be doing.

## Promises to content

- **BehaviorCap is an opt-in sub-resource on PropDef.** A PropDef without a `behavior` cap
  is not a creature — no AI will tick on it. Attaching a BehaviorCap via PropDef's `behavior`
  slot is the canonical way to opt in, and FaunaManager uses the presence of this cap (plus
  `spawnable`, `endurance`, and `movement`) to decide what counts as fauna worth spawning
  and ticking. See [`prop_def.md`](prop_def.md) for the composition model.
- **Default policy is "stationary, passive, omnipresent."** Every field has a sensible default
  so a BehaviorCap with no fields set describes an entity that is always active, sees a small
  radius, travels alone, eats nothing, and reacts to nothing. Content can author a creature
  with only one or two fields changed without breaking the cap.
- **`detection_range` is read in sub-hex rings.** A value of `2` means "two sub-hex rings out
  from the creature's current tile." FaunaManager uses this to decide when the player is
  close enough to trigger reactions or combat.
- **`activity_cycle` is honored by the spawn and tick loops.** A `DIURNAL` creature will be
  suppressed or asleep during night phases; a `NOCTURNAL` creature is the mirror. `ALWAYS`
  bypasses the cycle entirely. The exact suppression rule (does the creature despawn or just
  idle?) is FaunaManager's call; BehaviorCap only declares the intent.
- **`group_behavior` is a hint for the spawn loop.** When FaunaManager picks a count from
  `SpawnableCap.spawn_min`/`spawn_max`, it uses `group_behavior` to shape the cluster:
  `SOLO` forces 1, `PAIR` prefers 2, `PACK`/`HERD`/`SWARM` allow larger counts. The enum
  is advisory; SpawnableCap is still the source of truth for numeric bounds.
- **`diet` is a tag list, not a prop-id list.** Entries are `StringName` tags like `&"FLORA"`,
  `&"FAUNA"`, `&"MINERAL"`. A creature reacts to a prop as food by matching its `diet`
  against the target PropDef's `tags` array. Content can invent new diet tags freely; all
  that matters is that producers (the food's PropDef) and consumers (the creature's
  BehaviorCap) agree on spelling.
- **`reactions` is an array of GameEvent resources.** Each element is a reference to a
  `GameEvent` that FaunaManager (or a dedicated reaction evaluator) can fire in response to
  a stimulus. The array is typed `Array[Resource]` because GameEvent lives in a different
  script and GDScript's type system can't express the constraint directly, but the runtime
  convention is strict: every element must be a GameEvent.

## Requirements from content

- **Sub-resource shape, not a dictionary.** BehaviorCap must be authored as an inline
  `[sub_resource type="Resource"]` block in the parent PropDef `.tres`, with
  `script = ExtResource("behavior_cap")`. Dictionary-shaped data will not load.
- **Enum fields are integers on disk.** `activity_cycle` and `group_behavior` serialise as
  their integer values (0=ALWAYS, 1=DIURNAL, etc. for activity; 0=SOLO, 1=PAIR, etc. for
  group). Content-authoring tools should emit the numeric value, not the symbol name.
- **`diet` tags are `StringName`, not `String`.** Using plain strings will either fail the
  typed assignment or silently miss every match.
- **`reactions` elements must be GameEvent.** An `Array[Resource]` with non-GameEvent
  elements will load (Godot will not type-check the contents) but the runtime will fail
  when it tries to call GameEvent methods on them. Validators and editor tooling should
  check the class of each element.
- **BehaviorCap alone is not enough to make something tick.** FaunaManager requires the
  parent PropDef to also have `spawnable`, `endurance`, and `movement` before it will spawn
  and manage the creature. A PropDef with only `behavior` set will not appear in the world.

## Extension points

- **Adding new reactions.** Author a new GameEvent (precondition describes the stimulus,
  effects describe the response) and append it to the `reactions` array. No BehaviorCap
  code change is needed; the event system is the extension seam. This is how "flee from
  player," "call for help," "retreat to den at night" are all meant to be expressed.
- **Adding new diet tags.** Tags are free-form strings. A new diet entry like `&"NECTAR"`
  only requires that the food's PropDef also carries the tag. No central enum to update.
- **Adding new activity cycles.** The enum is closed and lives on BehaviorCap; extending it
  requires editing the script and rebuilding. Before adding a new cycle, consider whether
  the existing four plus `ALWAYS` fallback cover the case.
- **Adding new group topologies.** Same story as `activity_cycle`: the enum is closed.
  `SOLO`, `PAIR`, `PACK`, `HERD`, `SWARM` are the current vocabulary; new values require a
  script edit.
- **Overriding policy per creature instance.** BehaviorCap is shared between every instance
  of a given PropDef (all wolves share one cap). If a specific wolf needs a different
  detection range at runtime, that override must live on the creature's spawned node, not
  on the cap itself. The cap is immutable once loaded.

## Genre-specific notes

BehaviorCap is **Farhaven-specific — survival/ecology genre.** The fields make sense for a
game that simulates a living ecosystem of creatures: activity cycles tied to day/night,
diet-driven behavior, group topologies that match real-world animal organisation, detection
radii used for awareness checks. This is the "fauna AI block" for Farhaven's survival layer.

A second game would reuse this cap only if it ran a similar ecosystem simulation:

- **Would transfer cleanly.** A survival-sandbox, a life-sim, or a nature-management game
  could reuse BehaviorCap unchanged. The enum vocabularies (activity cycle, group behavior)
  and the diet-tag pattern are all genre-generic inside the ecology space.
- **Would need replacement.** A Civ-like strategic-AI opponent is a completely different
  shape — it plans turns, evaluates tech choices, coordinates armies — and shares no fields
  with a wolf's AI policy. A strategy game's "AI player" block would be its own class, not
  a repurposed BehaviorCap.
- **Would need hex/time reinterpretation.** `detection_range` is expressed in "sub-hex rings,"
  which is a Farhaven-specific spatial unit tied to HexGrid. A game on a square grid or a
  continuous plane would need to reinterpret the field or replace the unit. Similarly,
  `activity_cycle` assumes a day/night cycle exists, which is a real-time-world assumption.

The pragmatic framing: treat BehaviorCap as part of the "Farhaven survival capability pack."
Engine v2 reuse for a second survival/ecology game is straightforward; reuse for a different
genre means shipping a different cap in the `behavior` slot or removing the slot entirely.

## Known limitations and TODOs

- **No runtime "state machine" hook.** BehaviorCap describes policy, not current state. The
  creature's actual state (idling, fleeing, hunting) lives on the spawned fauna node and is
  not persisted or versioned on the cap. If a future refactor wants explicit state-machine
  authoring, it will need a new cap or a state-machine resource.
- **`reactions` is loosely typed.** Because `Array[GameEvent]` can't be expressed directly
  when GameEvent is in a different script, the field is `Array[Resource]` and runtime-checked.
  A future typed alias or a dedicated `ReactionEntry` sub-resource could tighten this.
- **`diet` is a flat tag list.** There is no priority ordering, no quantity, and no
  preference curve. A real carnivore that prefers deer but will eat rabbits when hungry
  cannot express that preference in the current schema.
- **`activity_cycle` suppression is FaunaManager's decision.** The cap declares intent but
  does not define the exact behavior during the off-cycle. This is correct layering but
  can surprise content authors who expect BehaviorCap to fully specify the lifecycle.
- **No combat integration.** BehaviorCap's reactions are non-combat by contract. Combat
  attacks and defenses live on CombatCap (which is itself a placeholder runtime; see
  [`combat_cap.md`](combat_cap.md) and delivery-006d task-088). The split between "reactive
  AI" and "combat moves" may need revisiting once the combat runtime lands.
