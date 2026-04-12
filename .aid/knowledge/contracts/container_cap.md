# ContainerCap

**Source:** `scripts/data/capabilities/container_cap.gd`
**Category:** core
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`inventory.md`](inventory.md), [`building_system.md`](building_system.md), [`recipe_runtime.md`](recipe_runtime.md)

## What this system is

ContainerCap marks a PropDef as "something that can hold other props inside it." Chests,
stockpiles, fireplaces (which contain fuel), and any station that stores inputs all get this
cap. The cap declares the container's storage as a rectangular grid of cells (`grid_width` ×
`grid_height`) and which prop types it is willing to accept (`accepts_filter`, a tag allowlist).
Actual storage state — the list of contained prop instances — lives on the world-side container
object, not on the cap. This means ContainerCap describes the *capability* (how big, what it
allows) while the live `Inventory` or container node on a specific chest describes the *current
contents*.

Items are placed into the container grid exactly as they are placed into the player's inventory:
a prop's `PortableCap.slot_shape` occupies one or more grid cells, and the container's grid
must have enough contiguous free cells to accept the shape. The shared currency between
ContainerCap and PortableCap is therefore **cell count** — `grid_width * grid_height` cells
available in the container versus the shape-area of each item that goes in.

## Promises to content

- **ContainerCap is opt-in via PropDef.** A PropDef without a `container` cap cannot hold
  props internally. Attaching a ContainerCap via PropDef's `container` slot is how a
  chest, barrel, or stockpile declares its storage.
- **`grid_width` and `grid_height` define the container grid.** The container presents a
  rectangular cell grid of exactly `grid_width × grid_height` cells. Default values are
  `grid_width = 30`, `grid_height = 40` (1200 cells), matching the player's base backpack
  size.
- **Items are placed into the grid by shape, not by scalar size.** A prop's
  `PortableCap.slot_shape` is what the container's placement logic fits into the grid,
  just as in the player's Tetris-style inventory. A prop occupies as many cells as its
  shape covers.
- **`accepts_filter` is an allowlist of tags.** If the list is non-empty, only props whose
  `tags` array matches one of the listed tags can go in. If the list is empty, the container
  accepts anything. This is the mechanism for "this container only holds fuel" or "this
  pantry only holds food."
- **Building system uses the compat `capacity_size` getter to grow player inventory.** When
  the player places a storage structure with a `container` cap, BuildingSystem reads
  `capacity_size` (which returns `grid_width * grid_height`) and adds that value to the
  player's `Inventory.capacity_size`, effectively expanding the pack size.
  [`building_system.md`](building_system.md) owns this contract. It works unchanged via the
  backward-compat getter — no migration needed on the BuildingSystem side.
- **Recipe runtime can treat a container as an input source.** `RecipeRuntime` and its
  `PredicateEvaluator` accept a `ctx.container` handle and will pull ingredients from it
  when a recipe's input is container-scoped. The fireplace-fuel pattern is the canonical
  example: the fireplace is a station, its attached container holds the fuel, and the
  cook recipe resolves inputs against the container before falling back to the tile or
  the player's bag.
- **ContainerCap is shared across instances.** Every chest of type `P00200` shares one
  ContainerCap. Per-instance storage state (the actual grid layout and contents) lives on
  the spawned chest node and is saved as part of the world state.

## Requirements from content

- **Sub-resource shape, not dictionary.** ContainerCap must be authored as an inline
  `[sub_resource type="Resource"]` block with `script = ExtResource("container_cap")`.
- **Author `grid_width` and `grid_height`, not `capacity_size`.** `capacity_size` no longer
  exists as a stored field. Specify the grid dimensions directly:
  ```
  grid_width = 6
  grid_height = 4
  ```
  Real examples: Campfire `P00101` = 6×4 (24 cells), Storage Chest `P00104` = 15×15
  (225 cells).
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

## Backward-compat `capacity_size` property

`capacity_size` is retained as a **computed, non-stored property** for legacy callers. It is
not exported and does not appear in `.tres` files.

- **Getter:** returns `float(grid_width * grid_height)`.
- **Setter:** reconstructs a near-square grid from the requested cell count so that
  `grid_width * grid_height ≈ value`. Useful for migration tooling; content should not
  rely on this setter for precise dimensions.

Code that already reads `container_cap.capacity_size` continues to work without changes.
New content and new engine code should use `grid_width` / `grid_height` directly. The
compat property is **transitional** and may be removed once all call sites migrate.

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
  delivery-006f.
- **Inventory expansion via building.** The BuildingSystem's "place chest → grow player
  capacity" pattern reads `capacity_size` via the compat getter, which returns
  `grid_width * grid_height`. This keeps BuildingSystem working without changes while
  ContainerCap migrates to grid dimensions.

## Genre-specific notes

ContainerCap is **fully genre-agnostic.** Every game with an inventory or placement system
has containers — chests, barrels, banks, stockpiles, caches, tech pools. The shape
(a rectangular grid plus an optional allowlist) is a minimal expression of "holds other
things, up to a limit, with a filter." A Civ-like second game could reuse ContainerCap
unchanged for its granary, treasury, or stockpile concepts. A Catan-like second game could
use it for resource hand limits.

The **only Farhaven-flavored piece** is the grid-cell currency shared with PortableCap and
the Tetris-style placement model. A game that measured inventory in simple item count rather
than shaped cells could replace the grid fields with a scalar — the `accepts_filter` and the
"cap describes potential, not contents" principle carry over unchanged regardless of the
capacity model.

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
- **No per-filter capacity.** A container cannot declare "up to 20 cells of FUEL and 10
  cells of FOOD." The limit is global across all accepted tags. Games that need per-tag
  budgets will need a richer schema.
- **Container-of-container save ordering.** A portable container (via both `portable` and
  `container` caps) round-trips through Godot's default serialisation, but the save
  system should be careful to serialise contents in a stable order — any non-determinism
  will produce diff-noisy saves. Flagged for the SaveManager contract review.
- **`capacity_size` compat property is transitional.** BuildingSystem and any other
  call site still using the scalar should migrate to reading `grid_width * grid_height`
  directly. The compat setter's near-square reconstruction may not produce the exact
  dimensions the caller intended; it exists for migration tooling only.
- **No contents-preview in the data class.** Authoring tools would benefit from a "what
  typically lives here" preview field, but adding it conflicts with the
  "cap describes potential, not contents" principle. Unlikely to change.
