# Inventory

**Source:** `scripts/inventory/inventory.gd`
**Category:** genre-specific
**Layer:** system
**Depends on:** [`prop_def.md`](prop_def.md), [`portable_cap.md`](portable_cap.md), [`prop_registry.md`](prop_registry.md). Owned by the Player, not an autoload. Consulted by [`auto_interaction_system.md`](auto_interaction_system.md), [`survival_system.md`](survival_system.md), [`building_system.md`](building_system.md), [`recipe_runtime.md`](recipe_runtime.md), and [`inventory_panel.md`](inventory_panel.md).

## What this system is

Inventory is Farhaven's **player-pouch data layer**. It is a `RefCounted` object (not a
Node) owned by the Player. It manages two concerns in one class:

1. **Prop / consumable slots** — a grid of slot dictionaries with per-type max-stack limits,
   primary-constraint *size-based* capacity (each item has a `PortableCap.size` that
   accumulates into a `capacity_size` budget), and add/remove/query API.
2. **Tool slots** — four fixed named slots (`&"axe"`, `&"pickaxe"`, `&"weapon"`, `&"scanner"`)
   that store a single PropDef id each. Tools live outside the prop grid entirely and are
   never subject to size constraints.

The separation is deliberate: the prop grid is for consumables and resources, which are
abundant and subject to carry-limit constraints; tool slots are for equipment, which is
singular and must never be subject to "you're too heavy to carry your axe" failure modes.

## Promises to content

- **Size is the primary constraint.** Every item has a size per unit derived from its
  `PortableCap.size` (items without a portable cap default to 1.0). Adding items is gated
  by the remaining `capacity_size`, not by slot count. A small number of large items can
  fill the inventory even with many empty slots.
- **Slot fragmentation is secondary.** Slots have `max_stack` limits; within a size budget,
  items still distribute across slots using partial-fill-first then empty-slot allocation.
  Same-type items are merged into existing partial stacks when possible.
- **`add_item(type, amount)` returns the amount actually added.** On capacity overflow,
  the return value is less than `amount` and `inventory_full(type, rejected)` fires. A
  complete rejection returns 0 and still emits `inventory_full`.
- **Items with a single-unit size exceeding total capacity are rejected fully.** You cannot
  carry an item whose size alone is greater than your max budget. This is a guardrail
  against absurdly large props sneaking into the inventory.
- **`remove_item(type, amount)` returns the amount actually removed.** Walks slots in
  reverse to minimise fragmentation. Emits `item_removed(type, amount)` and
  `inventory_changed()` on success.
- **`add_item` rejects tool-slot items.** Any PropDef with a non-empty `tool_slot` is
  rejected from the prop grid regardless of size. Tools must use `set_tool`.
- **Signals are the subscription surface.** `inventory_changed`, `item_added(type, amount)`,
  `item_removed(type, amount)`, `inventory_full(type, rejected)`, `item_used(type)`,
  `tool_changed(slot, new_tool, old_tool)`. InventoryPanel and HUD subscribe to these.
- **`use_item(type)` is a one-shot consume hook.** Removes one unit and emits
  `item_used(type)`. SurvivalSystem subscribes to `item_used` and dispatches to `consume(type)`
  to apply stat deltas. The panel calls `use_item` on tap.
- **Tool slots are four fixed StringNames.** `&"axe"`, `&"pickaxe"`, `&"weapon"`,
  `&"scanner"`. Adding a fifth slot requires editing the `_tool_slots` dict literal.
- **`set_tool(slot, tool)` returns the previous tool id.** `tool_changed(slot, new, old)`
  fires. Swapping tools does not go through the prop grid — the old tool is simply dropped
  (callers that want "return old tool to pouch" must handle it themselves).
- **`get_tool(slot)` returns `&""` if empty.** Querying an unknown slot also returns `&""`,
  never crashes.
- **`expand(additional_slots)` grows the grid.** Structures like the Storage Chest call this
  (via BuildingSystem's side-effect on place) to bump slot count. Bonus slots persist into
  save format.
- **`capacity_size` is mutable at runtime.** BuildingSystem directly writes
  `inv.capacity_size += 50.0` when a Storage Chest is placed. This is part of the data
  contract — external systems can bump capacity freely.
- **Save/load round-trips slots, bonus_slots, capacity_size, and tools.** Load recovers
  `capacity_size` from either the new key or the legacy `capacity_weight` key so older
  saves don't lose upgrades. Missing bonus_slots with larger saved slot arrays is handled
  by growing the total slot count to avoid silent data loss.

## Requirements from content

- **Owned by Player, accessed via `player.get_inventory()`.** Every system that needs the
  inventory walks up to the player and calls this method. Inventory is never an autoload.
- **PropRegistry must be initialised before add/remove/consume paths run.** Every lookup
  goes through `PropRegistry.get_def(type)` — an item whose type has no registered def is
  rejected from `add_item` (returns 0). Content cannot add arbitrary StringNames; only
  registered PropDef ids.
- **Items with `tool_slot` must use `set_tool`.** A prop authored as a tool (non-empty
  `tool_slot` field) cannot be added to the prop grid. Content that wants a tool to show up
  in inventory must call `set_tool(slot, id)`.
- **`PortableCap.size` drives the size budget.** Content can skip the cap for legacy items;
  the default size is 1.0 per unit. For v1 the main consumers of portable cap are resources
  and consumables that need "a small item takes little space."
- **Slot count defaults.** `_base_slots = 12`. Capacity can only grow via `expand`.

## Extension points

- **New tool slot.** Edit `_tool_slots` literal. Everything else (save format, UI row,
  signal routing) is driven off that dict.
- **New items.** Drop a new PropDef `.tres` with or without `PortableCap`; Inventory will
  accept it as soon as PropRegistry scans it.
- **New capacity bump mechanic.** Any system can write `inv.capacity_size += N`. BuildingSystem
  does this for Storage Chest; a future upgrade tree could do the same.
- **Panel integration.** InventoryPanel subscribes to `inventory_changed` and `tool_changed`
  and re-renders. Replacing the panel with a different UI only requires connecting those
  two signals. The contract is "tell me when something changed, I'll re-read."
- **Tests.** Because Inventory is a plain `RefCounted`, tests can construct one with `new()`,
  drive the API directly, and assert on the slot array. PropRegistry needs to be populated
  first (or the test doubles the registry).

## Genre-specific notes

Inventory is **survival-genre flavoured** but its internals are more reusable than they
look.

- **Size-based capacity is survival-genre typical.** Games with weight-based or volume-based
  inventories (Skyrim, The Long Dark, Don't Starve's slots-with-stacks) all have some
  version of this. A strategy game with abstract resources would drop it.
- **Tool slots as a separate namespace is survival-genre convention.** Survival games
  typically distinguish "equipment I carry" from "resources I carry" so that a full pouch
  can't lock you out of your tools. Combat RPGs do the same with "equipped" vs "inventory."
- **Max-stack + slot grid is retro-flavoured.** Minecraft-era inventory. Some modern games
  (Path of Exile, Diablo) use a grid of shaped items instead. The v1 model is deliberately
  simple.
- **Ground-drop-on-death is survival-flavoured.** Inventory itself doesn't own this logic —
  it's in `survival_system.md` — but the cooperation between the two (tool-slot skip +
  ground item emit) is deeply genre-specific.
- **Size-budget + slot-max dual constraint is Farhaven-specific.** The transition from
  slot-count-primary to size-primary is documented in the `max_stack` limitation notes in
  `prop_def.md`. The v1 dual model is transitional; long-term the plan is slot-units only.

A game that wants to replace Inventory outright can do so as long as it implements the
same public API: `add_item`, `remove_item`, `has_item`, `get_count`, `get_slots`, `is_full`,
`get_max_slots`, `get_used_slot_count`, `use_item`, `expand`, `get_tool`, `set_tool`,
`has_tool_for`, plus the signal set above. Every consumer in the engine calls through this
interface.

## Known limitations and TODOs

- **Dual size + slot constraint is a transitional.** `portable.size` is the primary constraint
  but `max_stack` still gates slot fill. The long-term direction is "one number — slot units
  — on PortableCap, no separate max_stack." See `prop_def.md` "max_stack is transitional."
- **No sorting / auto-arrange.** Slots accumulate in add order. A future pass could auto-
  consolidate same-type stacks.
- **No category tabs in prop grid.** All prop slots are one flat list. Survival games with
  larger inventories usually group resources vs consumables.
- **Capacity exceeded after a bonus-removal is possible.** If `expand(-10)` were ever
  supported, items might end up overhanging capacity. Currently there's no shrinking API,
  so this isn't a live bug.
- **Floating-point drift guard.** `_current_size` has an explicit `if _current_size < 0.0:
  _current_size = 0.0` guard for float drift. A future pass using integer sub-slot-units
  (e.g. 1 size = 100 sub-units) would eliminate the drift entirely.
- **Stack merging only on add.** If two stacks of the same type exist (via edit-time save
  manipulation) they won't auto-merge on subsequent writes. Normal play can't produce this
  situation.
- **Save format key churn.** The `capacity_weight` → `capacity_size` rename is handled on
  load but adds a little bit of back-compat noise. Cleanup deferred until pre-1.0 ships.
