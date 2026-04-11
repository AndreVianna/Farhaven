# PlaceableCap

**Source:** `scripts/data/capabilities/placeable_cap.gd`
**Category:** core
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`building_system.md`](building_system.md)

## What this system is

PlaceableCap is a **pure marker class**. It has no fields. Its entire purpose is to answer
one binary question: *"Can the player put this PropDef into the world?"* The presence or
absence of a PlaceableCap on a PropDef is the canonical gate for BuildingSystem: when the
player crafts a structure and tries to place it, BuildingSystem checks `def.placeable != null`
and either allows or rejects the placement. No other information is needed at the cap
level — everything about *how* the placement works (footprint, rotation, validity rules,
post-placement hooks) lives on the parent PropDef, on other caps, or in BuildingSystem
itself.

## Promises to content

- **PlaceableCap is opt-in via PropDef.** A PropDef without a `placeable` cap cannot be
  put into the world by the player. Adding the cap flips the flag; no other authoring is
  needed at the cap level.
- **Presence is the only semantic.** BuildingSystem reads `def.placeable != null` (and
  usually `def.has_tag(&"STRUCTURE")` alongside it) to decide whether a crafted output is
  something the player places versus something the player keeps in the bag. An empty
  PlaceableCap on a PropDef is sufficient to enable placement.
- **Footprint is not on PlaceableCap.** It lives on PropDef's deprecated `footprint` field
  and will migrate to a first-class slot in a future pass. The task-083a sample contract
  [`prop_def.md`](prop_def.md) describes the deprecation path — the comment in prop_def.gd
  says `"DEPRECATED in task-053: use placeable.footprint instead"`, but the field has not
  actually been moved onto PlaceableCap yet. Content authoring footprints today should
  still use the PropDef-level field.
- **Rotation, validity, and placement previews are BuildingSystem concerns.** The cap is
  silent about all of them by design.
- **PlaceableCap composes cleanly with any other cap.** It is frequently paired with
  `container` (storage chests), `light` (campfires), `station` (crafting benches),
  `portable` (placeable tools you can also carry), and `movable` (nudge-able crates).
  None of those compositions need any field on PlaceableCap — the marker alone is enough.
- **PlaceableCap is shared across instances.** All chests of type `P00200` share one
  PlaceableCap. Because the cap has no fields, "sharing" is trivial — there is nothing
  to share except the existence of the reference.

## Requirements from content

- **Sub-resource shape, not a dictionary.** Even though PlaceableCap has no fields, it
  must be authored as an inline `[sub_resource type="Resource"]` block with
  `script = ExtResource("placeable_cap")`. Content cannot express placeability by
  "setting a flag" — the cap must physically exist as a sub-resource.
- **BuildingSystem also checks for the `STRUCTURE` tag.** The current BuildingSystem
  implementation requires both `def.placeable != null` **and** `def.has_tag(&"STRUCTURE")`
  before it will drive a placement. Content authoring a buildable structure must set
  *both*. This is a convention, not a PlaceableCap rule — the tag check belongs to
  BuildingSystem's filter, not to the cap itself.
- **Placing a container expands inventory.** When a PropDef has both `placeable` and
  `container`, placing it triggers BuildingSystem to add `container.capacity_size` to
  the player's inventory capacity. This is a BuildingSystem-specific chain — the cap is
  innocent.
- **Do not add fields to PlaceableCap on a whim.** The marker-only shape is deliberate.
  Any new field should be justified against "could this live on PropDef or on another
  cap?" first.

## Extension points

- **(None — pure marker class.)** Because PlaceableCap has no fields, there is no field
  to extend. Extension happens at the composition level: compose PlaceableCap with other
  caps (ContainerCap, LightCap, StationCap, MovableCap) to build richer placed props.
  The cap itself is unchanging.
- **Future footprint slot.** The planned-but-unlanded migration is to add a `footprint:
  Array[Vector2i]` field so PropDef's deprecated field can be removed. When this lands,
  PlaceableCap will grow one field and this section will have something to document.
- **Future validity hooks.** A more ambitious future extension could add an array of
  placement-validity predicates (GameEvents with `can_place_here` preconditions). This
  is speculative and explicitly not scoped for delivery-006d.

## Genre-specific notes

PlaceableCap is **fully genre-agnostic.** "Can the player put this into the world?" is a
question any game with player-controlled placement — survival sandbox, city-builder, Civ,
tabletop-style strategy — will want to answer. Because the cap is a pure marker, reusing
it for a second game means literally nothing needs to change: any PropDef that should be
placeable attaches the same empty marker.

The **tag-coupling with `STRUCTURE`** (checked by BuildingSystem) is a Farhaven
convention. A second game might use a different tag (`BUILDABLE`, `UNIT`, `CITY`) or no
tag at all, depending on how its placement system filters candidates. The cap does not
care.

The **composition patterns** (placeable + container for storage, placeable + light for
campfires, placeable + station for crafting benches) are all reusable across genres —
what changes is which caps are present, not whether PlaceableCap is.

If a second game does not have player-driven placement at all, PlaceableCap is simply
unused and the `placeable` slot on PropDef stays null on every entry.

## Known limitations and TODOs

- **Zero-field shape is *intentional* but can feel anemic.** Content authors who open the
  script looking for "where do I set the footprint?" will find nothing. Documentation
  (this file, and the PropDef contract) needs to make the layering obvious: footprint
  is PropDef-level today and will migrate to the cap later.
- **Migration pending.** The comment in `prop_def.gd` asserts `footprint` is deprecated
  "in task-053: use placeable.footprint instead," but no `footprint` field actually
  exists on PlaceableCap. The migration was described in a prior delivery but not
  completed. Either the migration needs to land or the comment needs to be corrected.
  Scoping: out of 083c, flag for the 083e review.
- **Tag coupling is undeclared at the cap level.** BuildingSystem's requirement for a
  `STRUCTURE` tag alongside the cap is a two-sided contract (cap + tag) that lives
  entirely in BuildingSystem code. A future refactor could either move the tag check
  into the cap or add a dedicated `is_structure` flag, removing the tag dependency.
- **No validity-check hook.** The cap cannot express rules like "only on flat ground"
  or "must be adjacent to water." Those rules live in BuildingSystem and are hardcoded.
  A predicate-based validity system is desirable but unscoped.
- **Unit tests cover construction only.** Because there is nothing else to cover, the
  unit test surface for PlaceableCap is minimal. This is correct — a pure marker class
  does not need behavioral tests — but shows up in coverage audits as a low-coverage
  file and should be explained there.
