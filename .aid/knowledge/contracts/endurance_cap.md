# EnduranceCap

**Source:** `scripts/data/capabilities/endurance_cap.gd`
**Category:** genre-specific
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`combat_cap.md`](combat_cap.md), [`fauna_manager.md`](fauna_manager.md)

## What this system is

EnduranceCap is the hit-points-and-damage-tags block for anything that can take damage.
When a PropDef represents a creature, a breakable structure, or a destructible resource
node, attaching an EnduranceCap tells the combat/damage pipeline how much damage the prop
can absorb before being destroyed and how it reacts to each damage type. The shape is three
parallel tag lists — `vulnerabilities` (double damage), `resistances` (half damage), and
`immunities` (zero damage) — plus a single `hp` pool. EnduranceCap is the natural partner
of CombatCap: CombatCap describes the moves, EnduranceCap describes the body they hit.

## Promises to content

- **EnduranceCap is opt-in via PropDef.** A PropDef without an `endurance` cap is
  indestructible by the combat/damage pipeline. Attaching an EnduranceCap via PropDef's
  `endurance` slot is how a creature or breakable prop declares it has hit points.
- **`hp` is the single pool of survivability.** It is a plain `int` and defaults to `1`.
  When the accumulated damage reaches `hp`, the entity is destroyed (or knocked out, or
  despawned — exact semantics are the consumer's call; the cap only declares the budget).
- **Three damage-modifier lists, read in a fixed priority.** The intended evaluation is:
  `immunity > vulnerability > resistance`. An incoming damage tag in the immunity list
  deals zero damage and short-circuits further checks. Otherwise, a tag in the vulnerability
  list applies a 2x multiplier; a tag in the resistance list applies a 0.5x multiplier.
  The 2x and 0.5x constants are currently hardcoded in the damage pipeline
  *(see Known limitations — the pipeline is in fact not yet implemented; these are the
  documented intended multipliers that will land with the combat runtime).*
- **Damage tags are free-form `StringName`.** The usual suspects are `&"FIRE"`, `&"BLUNT"`,
  `&"PIERCING"`, `&"SLASHING"`, `&"COLD"`, `&"POISON"`, but any tag is legal as long as
  the attack side (CombatCap's attack GameEvents) and the defense side (EnduranceCap)
  agree on the spelling.
- **FaunaManager reads `hp` at spawn time.** When a creature is spawned, the manager uses
  `def.endurance.hp` as the creature's initial health. Per-instance state (current HP,
  damage taken) lives on the spawned node, not on the cap.
- **EnduranceCap is shared across instances.** Every wolf shares one EnduranceCap. The
  `hp` value is a spawn seed, not a live counter.

## Requirements from content

- **Sub-resource shape, not dictionary.** EnduranceCap must be authored as an inline
  `[sub_resource type="Resource"]` block with `script = ExtResource("endurance_cap")`.
- **`hp` is an `int`, defaults to 1.** Negative values or zero do not make sense and will
  likely cause the entity to be destroyed on its first damage tick (or at spawn). Use at
  least `1`.
- **Tag lists are `Array[StringName]`, not `Array[String]`.** Typed field enforcement will
  reject plain strings.
- **Tags are exact-match.** `&"FIRE"` does not match `&"FIRE.magical"`. If you want
  hierarchical damage types, list each leaf tag explicitly on the relevant lists. This is
  consistent with the PropDef tag system.
- **Do not put the same tag in two of the three lists.** The intended priority handles
  the conflict (immunity wins), but duplicating a tag across immunity and vulnerability
  is confusing for authors and makes reading a cap's intent harder. A validator could
  warn about this in the future.
- **A damageable prop that can attack back should also have a CombatCap.** EnduranceCap
  alone gives hit points but no moves. Most creatures carry both.

## Extension points

- **Adding new damage tags.** Free-form `StringName`. Coordinate with CombatCap producers
  (attacks that deal the tag) and EnduranceCap consumers (resistance/vulnerability/
  immunity lists that react to it). No central enum.
- **Adjusting multipliers.** The 2x/0.5x constants are hardcoded and will land in the
  combat runtime pipeline. A future refactor could push them onto EnduranceCap itself
  (e.g. `vulnerability_multiplier: float = 2.0`) to allow per-entity tuning. Out of scope
  for delivery-006d.
- **Non-damage consumers.** EnduranceCap's tag lists can be read by any subsystem that
  wants to ask "how does this prop react to X." For example, a SurvivalSystem check
  "can this creature survive in a frozen biome" could read the `immunities` list for
  `&"COLD"`. The cap's shape is general enough to support this without change.
- **Compound damage types.** If a future attack wants to deal `&"FIRE"` and `&"PIERCING"`
  simultaneously, the combat runtime iterates both tags and applies the worst-case
  multiplier. EnduranceCap does not need to change to support multi-tag damage; the
  iteration happens on the attack side.
- **Regeneration / decay.** EnduranceCap does not carry regen rates. A regenerating
  creature would need either a separate RegenCap or a regeneration field added here.
  Currently authored via periodic GameEvent effects on the creature; not ideal, but
  workable.

## Genre-specific notes

EnduranceCap is **Farhaven-specific — survival genre.** The very existence of "damage tags"
as a vulnerability/resistance/immunity triple is a survival/RPG pattern. A Civ-like or
Catan-like second game does not track damage types per unit — combat is resolved at the
army level, if it exists at all, with stat-based or card-based mechanics.

The genre fit breaks down across three dimensions:

- **HP is genre-generic.** Any unit with a destructibility concept has some form of HP. A
  strategy game might call it "strength" or "stack size," but the shape (single integer
  pool, destroyed at zero) transfers without friction.
- **The three parallel tag lists are survival-genre-specific.** The pattern is drawn from
  tabletop RPGs and action-RPG damage-type systems. It only pays off when attacks actually
  carry typed damage, which in turn requires a per-move combat system — and that is the
  Farhaven action/survival model. A strategy game that resolves combat with a single
  `attack_strength` vs `defense_strength` comparison would have no use for the lists.
- **The tag vocabulary is genre-specific.** `&"FIRE"`, `&"BLUNT"`, `&"COLD"` are fantasy/
  survival vocabulary. A sci-fi game would use `&"KINETIC"`, `&"ENERGY"`, `&"THERMAL"`. The
  tags themselves are free-form strings, so the vocabulary can be swapped without touching
  the cap.

Engine v2 reuse for another survival/RPG game is straightforward — ship the cap, pick a
tag vocabulary, author EnduranceCaps. Reuse for a strategy game means either leaving the
`endurance` slot unused or shipping a minimal EnduranceCap with only `hp` set and empty
tag lists.

## Known limitations and TODOs

- **Damage pipeline not yet implemented.** The contract described above — immunity
  short-circuit, vulnerability 2x, resistance 0.5x — is the *intended* behavior. There is
  no damage loop in delivery-006d that actually reads EnduranceCap and applies the
  multipliers. FaunaManager consumes `hp` at spawn time, but nothing currently subtracts
  from it or checks the tag lists. This lands alongside the combat runtime in
  **[delivery-006d task-088](../work-001-core/delivery-006d/DETAIL.md)**.
- **Multipliers are hardcoded.** 2x vulnerability and 0.5x resistance are not configurable
  per creature. A creature that is "mildly vulnerable to fire" (1.5x) or "completely
  destroyed by water" (5x) cannot express that nuance in the current schema.
- **No status-effect concept.** EnduranceCap handles direct HP damage but has no slot for
  damage-over-time, stun, slow, or other status effects. Those would need a separate cap
  or a status-policy sub-resource.
- **No armor / mitigation layer.** Flat damage reduction ("subtract 5 before multipliers")
  is not expressible. The multiplier-only model is the current design.
- **Immutable after load.** The cap is shared across all instances of a PropDef. Per-creature
  variation (e.g. boss versions of a base creature with more HP) must be authored as a
  separate PropDef with its own EnduranceCap, not as a runtime tweak.
- **No death-reward hook.** "When HP hits zero, drop X and fire event Y" is not on the cap.
  That lives in the combat runtime (pending) and in whatever GameEvent or recipe drives
  the loot drop. EnduranceCap declares survivability, not consequences.
