# MovableCap

**Source:** `scripts/data/capabilities/movable_cap.gd`
**Category:** core
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md)

## What this system is

MovableCap marks a PropDef as "something that has already been placed in the world but can
still be pushed, shoved, or repositioned without going back into an inventory." It is the
sibling of PlaceableCap: PlaceableCap says "this can be put into the world"; MovableCap
says "this, once in the world, is not rooted there." A crate, a wheeled cart, or a barrel
that can be nudged carries MovableCap. A foundation, a stone wall, or a campfire that
cannot be shoved after placement does not. MovableCap is the "this isn't furniture-glued
down" flag.

**⚠️ Note carefully: MovableCap is not MovementCap.** MovementCap (distinct file) is the
locomotion block for creatures — walk/swim/fly modes with per-mode speeds. MovableCap is
a world-level "can be pushed" marker for placed props. The two share a prefix but have
nothing else in common.

## Promises to content

- **MovableCap is opt-in via PropDef.** A PropDef without a `movable` cap represents a
  world prop that, once placed, stays rooted. Adding MovableCap makes it nudge-able by
  whatever world-interaction pipeline handles shoving.
- **`push_cost` is the cost in whatever currency the push system uses.** Defaults to `1.0`.
  The currency is deliberately unspecified at the cap level: a future push system might
  charge stamina, action points, a recipe duration, or nothing at all. The field declares
  the cost; the push system decides what it means.
- **MovableCap composes cleanly with PlaceableCap.** A prop that can be placed and then
  moved carries both caps. A prop that can be placed but not moved after carries only
  `placeable`. A prop that is permanently world-owned (e.g. part of the map generator
  output) and cannot be picked up but can still be shoved carries `movable` alone.
- **MovableCap says nothing about friction, momentum, or multi-tile pushes.** The cap
  holds a single cost field. Any richer physics must live in the push system that
  consumes the cap.
- **MovableCap is shared across instances.** Every crate of type `P00300` shares one
  MovableCap. Per-instance state (current position, last pushed timestamp) lives on the
  spawned node.

## Requirements from content

- **Sub-resource shape, not dictionary.** MovableCap must be authored as an inline
  `[sub_resource type="Resource"]` block with `script = ExtResource("movable_cap")`.
- **`push_cost` is a `float`.** Use `1.0` for "normal" (the default) and scale from
  there. Negative values are meaningless.
- **Do not confuse with MovementCap.** A creature moves via MovementCap.modes (sub-hex per
  second, WALK/SWIM/FLY/...). A placed prop is nudged via MovableCap.push_cost. Attaching
  both to the same PropDef is legal but rare — the only reasonable case is a mobile
  creature that also becomes a pushable object when knocked down, which the current
  runtime does not model.
- **Composition expectations.** Typically paired with `placeable` (to put it in the world
  in the first place) and sometimes `portable` (to pick it back up into the bag). A
  movable prop that is neither placeable nor portable is usually an authoring mistake.

## Extension points

- **Richer push physics.** Adding fields like `max_push_distance: int = 1`,
  `blocks_others: bool = true`, or `push_sound: AudioStream = null` would let authors
  shape how the prop responds to a nudge. These are straightforward additions — any new
  `@export` will round-trip and existing `.tres` files remain valid.
- **Cost-currency coupling.** If the push system is eventually implemented against a
  specific currency (e.g. stamina), a rename of `push_cost` to `push_stamina_cost` would
  clarify intent. Until then, the generic name is correct.
- **Multi-step push.** A prop that slides multiple tiles from a single shove could be
  authored by interpreting `push_cost` as "cost per tile" and adding a `push_inertia`
  field. Out of scope for delivery-006d.
- **Composable with Inventory handling.** If a future design wants "you can shove this or
  pick it up, depending on context," the existing pair of `movable` + `portable` on the
  same PropDef is already expressive enough; the two consumers just pick different paths.

## Genre-specific notes

MovableCap is **fully genre-agnostic.** "This world object is not rooted — you can push
it, and pushing costs X" is a concept any 2D or 3D game with interactable props might
want. A Civ-like second game could reuse MovableCap for units or caravans being relocated;
a Catan-like game could use it for pieces a player may reposition mid-turn. The shape —
a single float cost — is minimal enough to not constrain any interpretation.

There is no hex-grid or real-time assumption baked into the cap. The unit of `push_cost`
is up to whatever system consumes it: seconds for a real-time cost, action points for a
turn-based cost, tiles for a distance cost.

If a second game does not have a "push" concept at all, MovableCap is simply unused —
leave the `movable` slot null on every PropDef and no system will look at it.

## Known limitations and TODOs

- **No runtime consumer.** MovableCap is defined and serialises correctly, but no engine
  code currently reads `movable` to enable shoving, nudging, or repositioning. The push
  system is effectively vapor: the cap exists for forward compatibility and to reserve
  the slot on PropDef. Content can author the cap now, but it has no in-game effect.
  The runtime work is unscoped and likely lands in a future delivery (not delivery-006d).
- **Single-field surface.** One float is the entire cap. This is honest — the push system
  does not yet exist to require more — but content authors may expect `can_push_multi`,
  `push_direction`, or `push_through_walls` and find none of them.
- **No anchor / weight concept.** A light crate and a heavy chest both use the same
  `push_cost` field with no mass model. A future iteration could add a `mass` field or
  couple `push_cost` to PortableCap's `size`.
- **Naming collision with MovementCap.** The two caps share a prefix and sit next to each
  other on PropDef. Misattribution is easy. The naming was chosen before MovementCap
  existed; renaming one is a reasonable future cleanup but out of scope for 006d.
- **Not tested beyond construction.** The unit test coverage for MovableCap is minimal
  (construction + round-trip). There is no behavior to test yet — see "no runtime
  consumer" above.
