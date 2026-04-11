# PortableCap

**Source:** `scripts/data/capabilities/portable_cap.gd`
**Category:** core
**Layer:** data
**Depends on:** [`prop_def.md`](prop_def.md), [`inventory.md`](inventory.md), [`container_cap.md`](container_cap.md)

## What this system is

PortableCap is the "this prop can be carried in an inventory or container" slot. Tools,
weapons, food items, raw materials, crafted components, and every ingredient that flows
through the recipe system carries this cap. PortableCap is intentionally a single-field
class: it holds the item's **size** in slot-units, and nothing else. Size is the currency
the Inventory system uses to decide how much of a thing fits, and the same currency that
ContainerCap's `capacity_size` budgets against. A PropDef without a PortableCap is
understood as "not carryable" — something that lives in the world, not in a bag.

## Promises to content

- **PortableCap is opt-in via PropDef.** A PropDef without a `portable` cap cannot be
  put into the player's inventory or into a container. Adding the cap enables carry.
- **`size` is the slot-unit cost per item.** It is a `float` and defaults to `1.0`. The
  Inventory system multiplies `size` by the stacked quantity to compute how much space
  the stack occupies, and compares the total against `Inventory.capacity_size`.
- **`size` is the **post-006b** renamed field.** Older content and older documentation
  called it `weight`; it is now `size` to emphasise that the currency is slot-units, not
  grams. The SaveManager's load path still accepts the legacy `capacity_weight` key for
  backward compatibility with old saves (see [`inventory.md`](inventory.md)). New content
  must author `size`, not `weight`.
- **Size is the shared currency between PortableCap and ContainerCap.** A chest with
  `container.capacity_size = 50.0` holds fifty units of "size 1.0" items, or twenty-five
  units of "size 2.0" items, etc. The unit is abstract and applies equally to bag
  capacity and container capacity. This consistency is intentional — content authors
  learn one unit and apply it everywhere.
- **Fractional sizes are legal.** A `size` of `0.25` is meaningful (sixteen of these in
  a 4.0-capacity slot). The system uses floating-point math for the capacity checks, so
  fractional sizes do not require special handling.
- **PortableCap is shared across instances.** Every wood-log prop of type `P00080` shares
  one PortableCap. Per-instance state (which specific stack you are holding) lives on
  the Inventory's internal stack list.

## Requirements from content

- **Sub-resource shape, not dictionary.** PortableCap must be authored as an inline
  `[sub_resource type="Resource"]` block with `script = ExtResource("portable_cap")`.
- **`size` is a `float`.** Use `1.0` as the baseline and scale from there. Zero is legal
  but means "weightless" — the item takes no space in a bag, which breaks the "bag fills
  up" invariant; content should avoid zero unless intentional.
- **Do not re-introduce `weight` as a field name.** The rename from `weight` to `size`
  was a deliberate post-006b decision. The SaveManager accepts the legacy key on load
  only; the canonical authored field is `size`.
- **A tool prop that goes into a tool slot still needs PortableCap.** Tool slot handling
  on PropDef uses the `tool_slot` string to decide which slot an equipped tool occupies,
  but the underlying "can I even carry this?" gate still goes through PortableCap. A
  tool without PortableCap will not fit into any slot at all.
- **Placeable + portable composition.** A PropDef that is both carryable and placeable
  (a torch you can carry and put down, a chest you can pack up) gets both caps. The two
  are independent: PortableCap is read when the item enters or leaves a bag; PlaceableCap
  is read when the item is placed in the world.
- **max_stack transitional interaction.** PropDef still carries a legacy `max_stack`
  field that `Inventory.gd` reads alongside `size` to cap the per-slot count. `max_stack`
  is scheduled for removal in favor of pure slot-unit math. Content should author `size`
  as the load-bearing field and treat `max_stack` as legacy. See [`prop_def.md`](prop_def.md)
  *Known limitations* for the transition story.

## Extension points

- **Adding new per-item metadata.** Fields like `durability`, `quality`, or `tier` could
  live on PortableCap if they are always read at carry-time. In practice, per-item
  variation lives on the Inventory stack, not on the cap, because all instances of a
  PropDef share the cap. If per-PropDef tiering is needed (e.g. "iron axe" vs "steel
  axe" as different PropDefs), each one ships its own PortableCap anyway.
- **Stack-overriding.** A PropDef could in principle override inventory rules via
  PortableCap — e.g. `no_stacking: bool = false` to force items into separate slots. Not
  on the current cap; add if content needs it.
- **Currency coupling.** A game that uses weight and volume as separate dimensions could
  add a `volume` field alongside `size` and teach Inventory to budget against both.
  Out of scope for delivery-006d; the single-dimension slot-unit system is the current
  design.
- **Composition with ContainerCap.** A carryable container (a backpack, a quiver)
  combines `portable + container`. The Inventory system handles this by nesting: the
  outer inventory holds a stack-of-one of the backpack, and the backpack exposes its
  own inner inventory. Save ordering is delicate — see ContainerCap's Known limitations.

## Genre-specific notes

PortableCap is **fully genre-agnostic.** Every game with player-side carrying — survival
sandbox, dungeon crawler, RPG, strategy game with caravan limits, card game with hand
sizes — needs a "how big is this item" concept. The single-float shape is a minimal
expression of that.

The **unit of `size`** is deliberately abstract. Farhaven calls it "slot-units" and uses
it as a blend of weight-and-volume. A second game is free to reinterpret: a card game
could treat `size` as "card count," a strategy game could treat it as "population cost,"
a realistic sim could treat it as "kilograms." The field is a plain float — the meaning
is entirely in how Inventory and ContainerCap consume it.

The **baseline-of-1.0 convention** is a Farhaven authoring norm, not a technical
requirement. A second game could pick 10.0 or 100.0 as its baseline to leave room for
integer approximations. As long as producers (PortableCap.size) and consumers
(Inventory.capacity_size, ContainerCap.capacity_size) agree on the scale, the system
works.

The **rename from `weight` to `size`** was a Farhaven clarity pass; it is not meaningful
across genres. A second game is free to use either term internally.

## Known limitations and TODOs

- **Single-dimension budget.** PortableCap encodes one scalar. Weight and volume as
  separate dimensions are not representable. A game that wanted both would either add a
  `volume` field to the cap or introduce a second cap. For now, "size" is the conflation.
- **Transitional coexistence with `max_stack`.** The Inventory system currently uses both
  `PortableCap.size` and `PropDef.max_stack` to enforce slot limits. The long-term
  direction is pure slot-unit math, but the transition is not yet complete. Content
  should be aware of both until the clean-up happens.
- **No per-instance variation in the cap.** A half-durability axe and a full-durability
  axe both read `size` from the same cap. Variation must live on the Inventory stack
  record, not here. This is a correct layering but can surprise authors expecting a
  `current_durability` field on the cap.
- **No quantity-gated packing.** `size = 0.5` items pack at 0.5 per count — there is no
  notion of "you need space for the whole item plus wrapping." Most games do not need
  this, but it is worth flagging.
- **SaveManager accepts legacy `capacity_weight` key.** On load, the inventory capacity
  field is set from whichever of `capacity_size` or `capacity_weight` is present. This
  is a compatibility shim that will be removed in a future delivery. New saves write
  `capacity_size` only.
- **Tool slots bypass size math in one place.** Tools occupy a named tool-slot on
  Inventory regardless of their `size` (an axe goes in the "axe" slot). PortableCap is
  still required for the item to exist in the inventory at all, but the tool-slot path
  does not budget against `capacity_size`. This is intentional but authors should know.
- **Zero-size items.** Technically legal, practically pathological. A future validator
  could warn about `size <= 0.0`.
