# CombatCap

**Source:** `scripts/data/capabilities/combat_cap.gd`
**Category:** genre-specific
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`endurance_cap.md`](endurance_cap.md), [`event_registry.md`](event_registry.md) *(runtime pending — see delivery-006d task-088)*

## What this system is

CombatCap is the attack/defense block for anything that can fight. When a PropDef represents
a creature or structure that participates in combat, attaching a CombatCap lists the moves it
can perform and the responses it can trigger. CombatCap is intentionally expressed as two
arrays of `GameEvent` resources — `attacks` and `defenses` — rather than as a hand-rolled
damage schema. The idea is that combat in Farhaven composes from the same event machinery
that drives the rest of the engine: an attack is a GameEvent with a precondition
("target in range, cooldown elapsed") and an effect ("deal damage with tag FIRE"); a defense
is a GameEvent with a precondition ("being attacked with tag BLUNT") and an effect
("reduce incoming damage"). This keeps the shape uniform and leaves the details to the
event definitions.

**⚠️ Runtime not yet implemented.** The shape is authored and round-trips through saves, but
there is no combat loop in delivery-006d that reads `attacks`/`defenses` and dispatches them.
The fields are `Array[Resource]` placeholders until the combat runtime lands. See
**[delivery-006d task-088](../../work-001-core/delivery-006d/DETAIL.md)** for the scheduled fix.

## Promises to content

- **CombatCap is opt-in via PropDef.** A PropDef without a `combat` cap is non-combatant by
  definition. Attaching a CombatCap via PropDef's `combat` slot is the canonical way to opt
  in. A prop can have CombatCap alone (a turret) or combined with BehaviorCap/MovementCap/
  EnduranceCap (a mobile creature).
- **Shape is symmetric: attacks and defenses are both arrays of GameEvent.** The engine does
  not privilege one over the other. Attacks are initiated by the owner; defenses are
  triggered by incoming damage. Everything else — damage type, target filter, cooldown —
  lives on the GameEvent itself.
- **An empty array is valid.** A creature with no attacks can still have defenses, and vice
  versa. A prop with both arrays empty has a CombatCap in name only and will behave like
  one with no cap at all.
- **Defense evaluation happens against damage tags.** The intended contract is: when damage
  is dealt to an entity with a CombatCap, its `defenses` list is scanned for any
  GameEvent whose preconditions match the incoming damage type. Matching defenses fire
  their effects (reduce, reflect, absorb). Damage-type tags are the glue between
  `CombatCap.defenses` and `EnduranceCap.vulnerabilities`/`resistances`/`immunities`.
- **CombatCap does not own HP.** Hit points live on [`endurance_cap.md`](endurance_cap.md).
  CombatCap only describes the offensive and defensive moveset; damage application and
  survival checks are EnduranceCap's concern.
- **CombatCap is shared across instances.** All wolves share one CombatCap. Per-instance
  state (cooldown timers, last-attack timestamp) must live on the spawned entity, not
  on the cap.

## Requirements from content

- **Sub-resource shape, not dictionary.** CombatCap must be authored as an inline
  `[sub_resource type="Resource"]` block with `script = ExtResource("combat_cap")`.
- **Array elements must be GameEvent.** Both `attacks` and `defenses` are declared as
  `Array[Resource]` because GDScript can't directly type against GameEvent when it lives
  in a different script file. The runtime convention is strict: every element is a
  GameEvent. Non-GameEvent elements will load but will fail the combat runtime once it
  lands.
- **Damage type tags must be consistent.** An attack whose effect deals `&"FIRE"` damage
  is resisted only by EnduranceCaps that list `&"FIRE"` in their resistance/immunity
  arrays. Typos silently do nothing. A future validator could cross-check.
- **A prop that wants hit points must also carry `endurance`.** CombatCap alone does not
  create a damageable entity. The pattern is: CombatCap for moves, EnduranceCap for
  survivability, both on the same PropDef.

## Extension points

- **Adding a new attack.** Author a new GameEvent with the desired precondition and effect,
  then append it to the `attacks` array on the relevant CombatCap. No CombatCap code
  change needed — the event system is the extension seam.
- **Adding a new defense type.** Same story as attacks: new GameEvent with matching
  preconditions, appended to `defenses`.
- **Adding new damage tags.** Tags are free-form `StringName`. Coordinate between attack
  effects (producers) and EnduranceCap vulnerability/resistance/immunity lists (consumers).
  No central enum.
- **Custom damage formulas.** Because damage is applied as a GameEvent effect, a new
  "damage with critical chance" or "damage scaled by attribute" formula is added by writing
  a new GameEvent effect, not by touching CombatCap. This keeps the cap shape stable.
- **Combined AI + combat.** When the combat runtime lands, BehaviorCap's detection range
  and activity cycle will gate when a creature looks for combat targets, and CombatCap
  will describe what it does once a target is found. The two caps are complementary.

## Genre-specific notes

CombatCap is **Farhaven-specific — survival/RPG genre.** The "attacks and defenses as
GameEvent arrays" shape is biased toward an action-RPG survival game where individual
creatures trade blows in real time. Genre-generic design lives at the GameEvent level;
CombatCap is the Farhaven-specific arrangement of it.

A second game would likely reuse this cap only if it ran a similar moment-to-moment combat
model:

- **Would transfer reasonably.** Any survival sandbox, action RPG, or dungeon crawler with
  per-creature attack/defense moves can reuse CombatCap once the runtime lands. The
  event-as-move pattern is flexible enough for most moveset designs.
- **Would not transfer.** A Civ-like strategy game does not track individual creature
  attacks — combat is resolved at the unit or army level with stat comparisons or
  probabilistic rolls. Its "combat block" would be stats, not a list of event moves.
  CombatCap would not be a useful starting point.
- **Damage-tag coupling is genre-specific.** The convention that attacks carry tags like
  `&"FIRE"`, `&"BLUNT"`, `&"PIERCING"` and that EnduranceCap reacts to them is a survival/
  fantasy pattern. A sci-fi game might use `&"KINETIC"`, `&"ENERGY"`, `&"PLASMA"`; a
  strategy game might use `&"MELEE"`, `&"RANGED"`, `&"SIEGE"`. The tag system itself is
  genre-neutral — only the tag vocabulary changes.

Farhaven treats CombatCap as part of the "survival capability pack." Engine v2 reuse for
another survival/action game is straightforward once the runtime is in place; reuse for a
strategy game means shipping a different combat resource entirely and leaving the `combat`
slot on PropDef unused for strategy-game props.

## Known limitations and TODOs

- **🚨 Combat runtime not implemented.** The single biggest gap. `attacks` and `defenses`
  are authored and serialise correctly, but no engine code reads them and dispatches the
  events as combat moves. Adding, removing, or editing entries today has zero runtime
  effect. This is explicitly scheduled for
  **[delivery-006d task-088](../../work-001-core/delivery-006d/DETAIL.md)**. Until then,
  CombatCap is a shape-only contract.
- **Array typing is loose.** `attacks` and `defenses` are `Array[Resource]` rather than
  `Array[GameEvent]` because of the cross-script type constraint. This is a GDScript
  limitation, not a design choice, and it means content can author garbage elements
  without load errors.
- **No cooldown management at the cap level.** The current shape has no per-move cooldown
  field. The assumption is that each attack GameEvent carries its own cooldown in its
  preconditions. This is workable but diffuses cooldown state across many events; a
  dedicated `cooldown` field on the attack entry might be cleaner once the runtime lands.
- **No aggro / threat model.** CombatCap describes moves, not targeting priority. When the
  runtime lands, target selection will need to live somewhere — probably in BehaviorCap or
  a dedicated ThreatCap. The split is undecided.
- **No animation hook.** CombatCap says nothing about what animation plays when an attack
  fires. That binding (attack id → animation) will need to live in the creature's spawned
  scene or in a parallel animation-policy resource. Out of scope for delivery-006d.
- **Interaction with EnduranceCap damage tags is undefined until runtime.** The intent is
  clear — attacks carry damage tags, defenses and EnduranceCap react to them — but the
  actual dispatch loop does not exist. Damage-tag semantics (stack order, multiplier
  rules, immunity-overrides-resistance) are all pending resolution at runtime time.
