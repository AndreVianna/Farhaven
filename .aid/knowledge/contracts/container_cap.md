# ContainerCap

**Source:** `scripts/data/capabilities/container_cap.gd`
**Category:** core
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`inventory.md`](inventory.md), [`building_system.md`](building_system.md), [`recipe_runtime.md`](recipe_runtime.md)

## What this system is

ContainerCap marks a PropDef as "something that can hold other props inside it." Chests,
stockpiles, fireplaces (which contain fuel), and any station that stores inputs all get this
cap. The cap itself is intentionally thin: it declares how much the container can hold
(`capacity_size`, in the same slot-unit currency that `PortableCap.size` uses) and which
prop types it is willing to accept (`accepts_filter`, a tag allowlist). Actual storage state
— the list of contained prop instances — lives on the world-side container object, not on
the cap. This means ContainerCap describes the *capability* (how big, what it allows) while
the live `Inventory` or container node on a specific chest describes the *current contents*.

## Promises to content

- **ContainerCap is opt-in via PropDef.** A PropDef without a `container` cap cannot hold
  props internally. Attaching a ContainerCap via PropDef's `container` slot is how a
  chest, barrel, or stockpile declares its storage.
- **`capacity_size` is expressed in slot-units, matching PortableCap.** The same unit system
  that controls inventory fills controls container fills, so a storage chest that grants
  `capacity_size = 50.0` gives its owner 50 slot-units of space — comparable directly to
  how many `portable.size` units of stuff fit into the player's base inventory.
- **`accepts_filter` is an allowlist of tags.** If the list is non-empty, only props whose
  `tags` array matches one of the listed tags can go in. If the list is empty, the container
  accepts anything. This is the mechanism for "this container only holds fuel" or "this
  pantry only holds food."
- **Building system uses `capacity_size` to grow player inventory.** When the player places
  a storage structure with a `container` cap, BuildingSystem reads `capacity_size` and adds
  it to the player's `Inventory.capacity_size`, effectively expanding the pack size.
  [`building_system.md`](building_system.md) owns this contract.
- **Recipe runtime can treat a container as an input source.** `RecipeRuntime` and its
  `PredicateEvaluator` accept a `ctx.container` handle and will pull ingredients from it
  when a recipe's input is container-scoped. The fireplace-fuel pattern is the canonical
  example: the fireplace is a station, its attached container holds the fuel, and the
  cook recipe resolves inputs against the container before falling back to the tile or
  the player's bag.
- **ContainerCap is shared across instances.** Every chest of type `P00200` shares one
  ContainerCap. Per-instance storage state (the actual slots and their contents) lives on
  the spawned chest node and is saved as part of the world state.

## Requirements from content

- **Sub-resource shape, not dictionary.** ContainerCap must be authored as an inline
  `[sub_resource type="Resource"]` block with `script = ExtResource("container_cap")`.
- **`capacity_size` is a `float` in slot-units.** Use the same unit vocabulary as
  PortableCap so authors can reason consistently about "how much fits where." A
  `capacity_size` of 0.0 means "no storage" and is effectively a no-op ContainerCap —
  valid but useless.
- **`accepts_filter` entries are `StringName`, not `String`.** Using plain strings will
  fail the typed assignment or silently miss every tag match.
- **Tag matching is exact, not hierarchical.** A filter of `&"BURNABLE"` will not match a
  prop tagged `&"BURNABLE.log"`. Content that wants hierarchical filtering must list every
  leaf tag explicitly — this is consistent with the PropDef tag system (see
  [`prop_def.md`](prop_def.md) *Known limitations*).
- **The prop must also be `placeable` if it is a world container.** ContainerCap alone does
  not place a chest in the world; the PropDef must also carry a `placeable` cap so the
  BuildingSystem can put it down. This is a composition requirement, not a ContainerCap
  requirement.
- **Contents are not declared on the cap.** Content authors expecting to pre-fill a chest
  at authoring time must do it through a spawn hook, not through ContainerCap. The cap
  describes potential, not contents.

## Extension points

- **Adding a typed container.** Set `accepts_filter` to the list of tags the container
  accepts. No code change needed — recipe inputs and the inventory drop logic read
  the filter directly.
- **Composing with StationCap.** A crafting station that reads from its own container is
  authored by attaching both `container` and `station` caps to the same PropDef. The
  recipe runtime's `ctx.container` and `ctx.station` hooks handle the dispatch; the caps
  themselves have no awareness of each other.
- **Composing with PortableCap.** A portable container (a basket) is authored by attaching
  both `portable` and `container` caps. Note that serialising a container-of-containers
  through the save system requires care — see Known limitations.
- **Adding new filter semantics.** The current `accepts_filter` is "accept if any tag
  matches." More sophisticated rules (reject lists, capacity-per-tag) would require
  extending the cap with new fields or a paired predicate resource. Out of scope for
  delivery-006d.
- **Inventory expansion via building.** The BuildingSystem's "place chest → grow player
  capacity_size" pattern is one concrete consumer of `capacity_size`. Other consumers
  (e.g. a crafting station that uses the field as "max simultaneous recipes") can read
  the same field without adding a new one.

## Genre-specific notes

ContainerCap is **fully genre-agnostic.** Every game with an inventory or placement system
has containers — chests, barrels, banks, stockpiles, caches, tech pools. The shape
(capacity plus optional allowlist) is a minimal expression of "holds other things, up to a
limit, with a filter." A Civ-like second game could reuse ContainerCap unchanged for its
granary, treasury, or stockpile concepts. A Catan-like second game could use it for resource
hand limits.

The **only Farhaven-flavored piece** is the slot-unit currency shared with PortableCap.
A game that measured inventory in count or in grid cells instead of slot-units would
reinterpret `capacity_size` as that unit — the field is a plain `float` and does not assume
any particular meaning at the class level. The meaning comes from how PortableCap and the
Inventory system interpret the number, not from ContainerCap itself.

The **`accepts_filter`** tag vocabulary is similarly genre-neutral — filters can be
`&"RESOURCE"` or `&"FUEL"` or `&"TECH_CARD"` depending on the game. The cap does not
privilege any particular vocabulary.

## Known limitations and TODOs

- **`accepts_filter` has no runtime consumer today.** The field is defined and round-trips
  through serialisation, and test fixtures cover its shape, but no engine code currently
  reads it to reject an insertion. The field exists for forward compatibility with a
  filtering layer that will land alongside the storage-station work. Content can author
  the filter now; it becomes load-bearing once the runtime hook is added.
- **Exact-match tags only.** The same flatness that affects PropDef tag lookup affects the
  filter: `&"BURNABLE"` does not match `&"BURNABLE.log"`. A hierarchy system is future
  work.
- **No per-filter capacity.** A container cannot declare "up to 20 units of FUEL and 10
  units of FOOD." The limit is global across all accepted tags. Games that need per-tag
  budgets will need a richer schema.
- **Container-of-container save ordering.** A portable container (via both `portable` and
  `container` caps) round-trips through Godot's default serialisation, but the save
  system should be careful to serialise contents in a stable order — any non-determinism
  will produce diff-noisy saves. Flagged for the SaveManager contract review.
- **Building-driven capacity expansion is hard-wired.** `BuildingSystem` reads
  `container_cap.capacity_size` and adds it to the player's inventory when a storage
  structure is placed. This is a specific convention, not a general mechanism; reversing
  it (destroying the chest to shrink the bag) is handled elsewhere and is out of scope
  for ContainerCap itself.
- **No contents-preview in the data class.** Authoring tools would benefit from a "what
  typically lives here" preview field, but adding it conflicts with the
  "cap describes potential, not contents" principle. Unlikely to change.
