# PortableCap

**Source:** `scripts/data/capabilities/portable_cap.gd`
**Category:** core
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`inventory.md`](inventory.md), [`container_cap.md`](container_cap.md)

## What this system is

PortableCap is the "this prop can be carried in an inventory or container" slot. Tools,
weapons, food items, raw materials, crafted components, and every ingredient that flows
through the recipe system carries this cap. PortableCap is intentionally a single-field
class: it holds the item's **slot shape** as an array of cell offsets, and nothing else.
Shape is the currency the Inventory system uses to decide how a thing fits on the 2D grid,
and cell count (the number of occupied cells) is the shared unit between PortableCap and
ContainerCap's grid dimensions. A PropDef without a PortableCap is understood as "not
carryable" — something that lives in the world, not in a bag.

## Promises to content

- **PortableCap is opt-in via PropDef.** A PropDef without a `portable` cap cannot be
  put into the player's inventory or into a container. Adding the cap enables carry.
- **`slot_shape` is the item's spatial footprint.** It is an `Array[Vector2i]` and
  defaults to `[Vector2i(0, 0)]` (a single cell, 1×1 item). Each element is a cell
  offset relative to the item's origin cell `(0, 0)`. The Inventory system places the
  item's origin at a chosen grid cell and then claims every offset in `slot_shape` as
  occupied.
- **Cell count is the shared currency between PortableCap and ContainerCap.** A container
  defined as a `grid_width × grid_height` grid holds exactly that many cells. An item's
  contribution to that budget is `slot_shape.size()` — the number of cells it occupies,
  regardless of shape. The unit is abstract and applies equally to inventory grids and
  container grids.
- **Items can have irregular shapes.** L-shapes, T-shapes, straight lines, 2×2 blobs, and
  arbitrary connected regions are all legal. The only authoring constraint is that offsets
  are expressed in integer cell coordinates relative to the item's origin.
- **PortableCap is shared across instances.** Every wood-log prop of type `P00080` shares
  one PortableCap. Per-instance state (which specific slot the item occupies) lives on
  the Inventory's internal grid state.
- **Rotation is handled by the grid engine, not by PortableCap.** Authors define the base
  (0°) orientation only. The Inventory system applies rotation transforms when placing
  or rotating items. PortableCap has no rotation field.

## Requirements from content

- **Sub-resource shape, not dictionary.** PortableCap must be authored as an inline
  `[sub_resource type="Resource"]` block with `script = ExtResource("portable_cap")`.
- **`slot_shape` is an `Array[Vector2i]`.** The minimum valid value is `[Vector2i(0, 0)]`
  (one cell). The origin cell `(0, 0)` must be included — it is the anchor point the
  Inventory system uses for placement. An empty array is technically legal but means the
  item occupies no cells, which breaks grid accounting; content should avoid it.
- **Author the base orientation only.** Do not encode rotated variants in `slot_shape`.
  Rotation is a grid-engine concern. The authored shape is the 0° reference.
- **A tool prop that goes into a tool slot still needs PortableCap.** Tool slot handling
  on PropDef uses the `tool_slot` string to decide which slot an equipped tool occupies,
  but the underlying "can I even carry this?" gate still goes through PortableCap. A
  tool without PortableCap will not fit into any slot at all.
- **Placeable + portable composition.** A PropDef that is both carryable and placeable
  (a torch you can carry and put down, a chest you can pack up) gets both caps. The two
  are independent: PortableCap is read when the item enters or leaves a bag; PlaceableCap
  is read when the item is placed in the world.

## Shape examples

These are the canonical base shapes from the current .tres files:

| Item | Cells | Shape |
|------|-------|-------|
| Berry | 1 | `[Vector2i(0,0)]` — single cell |
| Wood | 2 | `[Vector2i(0,0), Vector2i(1,0)]` — horizontal line |
| Bone | 3 | `[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]` — horizontal line |
| Stone | 4 | `[Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]` — 2×2 blob |
| Knife | 6 | `[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(3,1), Vector2i(2,1)]` — L-shape |
| Axe | 15 | irregular L-shape |
| Pickaxe | 18 | irregular L-shape |

## Extension points

- **Adding new per-item metadata.** Fields like `durability`, `quality`, or `tier` could
  live on PortableCap if they are always read at carry-time. In practice, per-item
  variation lives on the Inventory's grid state, not on the cap, because all instances of
  a PropDef share the cap. If per-PropDef tiering is needed (e.g. "iron axe" vs "steel
  axe" as different PropDefs), each one ships its own PortableCap anyway.
- **Multi-orientation authoring.** A future system could store multiple `slot_shape`
  variants per item (one per rotation step) on the cap rather than computing them in the
  grid engine. Not on the current cap; the engine-driven rotation approach is the current
  design.
- **Currency coupling.** A game that tracks both cell footprint and a weight budget could
  add a `weight` field alongside `slot_shape` and teach Inventory to budget against both.
  Out of scope for delivery-006f; cell count is the current single dimension.
- **Composition with ContainerCap.** A carryable container (a backpack, a quiver)
  combines `portable + container`. The Inventory system handles this by nesting: the
  outer inventory holds the backpack item on its grid, and the backpack exposes its own
  inner inventory grid. Save ordering is delicate — see ContainerCap's Known limitations.

## Genre-specific notes

PortableCap is **fully genre-agnostic.** Every game with player-side carrying — survival
sandbox, dungeon crawler, RPG, strategy game with caravan limits — needs a "what shape is
this item" concept. The array-of-cell-offsets model is a minimal expression of that.

The **grid cell** is deliberately abstract. Farhaven uses it as a blend of spatial size
and encumbrance. A second game is free to reinterpret: a dungeon crawler could treat each
cell as one "bag slot," a strategy game could treat cell count as "supply cost," a
realistic sim could assign physical meaning to each cell. The field is a plain
`Array[Vector2i]` — the meaning is entirely in how Inventory and ContainerCap consume it.

The **default 1×1 convention** (a single `[Vector2i(0,0)]`) is a sensible baseline for
small items. Games with finer granularity can use more cells for even small items to give
the grid engine more resolution.

The **irregular shape support** is intentional for Farhaven's survival tone: an axe
feeling different to carry than a berry is part of the inventory puzzle. A second game
targeting a simpler inventory model could restrict itself to rectangular shapes by
convention without any code change.

## Known limitations and TODOs

- **Shape must be a connected region.** The grid engine does not enforce connectivity, but
  an item with disjoint cells (holes in the footprint) will produce unexpected placement
  behavior. Authors should keep shapes as single connected regions.
- **No per-instance variation in the cap.** A half-durability axe and a full-durability
  axe both read `slot_shape` from the same cap. Variation must live on the Inventory grid
  state record, not here. This is a correct layering but can surprise authors expecting a
  `current_durability` field on the cap.
- **No quantity-gated packing.** 1×1 items each occupy one cell regardless of stack count
  — there is no notion of bulk packing. The grid model is one-prop-one-shape; stacking is
  not part of the current model.
- **Tool slots bypass shape placement in one path.** Tools occupy a named tool-slot on
  Inventory regardless of their `slot_shape` (an axe goes in the "axe" slot). PortableCap
  is still required for the item to exist in the inventory at all, but the tool-slot path
  does not perform grid placement against the shape. This is intentional but authors
  should know.
- **Zero-cell shape.** An empty `slot_shape` array is technically legal but pathological.
  A future validator could warn about `slot_shape.is_empty()`.
