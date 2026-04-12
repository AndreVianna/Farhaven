# Inventory

**Source:** `scripts/inventory/inventory.gd`
**Category:** genre-specific
**Layer:** system
**Depends on:** [`prop_def.md`](prop_def.md), [`portable_cap.md`](portable_cap.md), [`prop_registry.md`](prop_registry.md). Owned by the Player, not an autoload. Consulted by [`auto_interaction_system.md`](auto_interaction_system.md), [`survival_system.md`](survival_system.md), [`building_system.md`](building_system.md), [`recipe_runtime.md`](recipe_runtime.md), and [`inventory_panel.md`](inventory_panel.md).

## What this system is

Inventory is Farhaven's **player-pouch data layer**. It is a `RefCounted` object (not a
Node) owned by the Player. It manages two concerns in one class:

1. **Grid-based item storage** — a 2D grid (`grid_width × grid_height` cells, default 30×40).
   Each item occupies a set of cells defined by its `PortableCap.slot_shape` (an
   `Array[Vector2i]` of cell offsets relative to an origin). Items can be rotated in 90°
   increments (4 orientations). There is no stacking: one prop instance occupies exactly
   one shape on the grid. The grid is stored as a flat `PackedInt32Array` where each cell
   holds an `item_id` (0 = empty). Items are tracked in a dict keyed by `item_id`; ids are
   assigned sequentially and never reused within a session.

2. **Tool slots** — four named slots (`&"axe"`, `&"pickaxe"`, `&"weapon"`, `&"scanner"`).
   Scanner is body-integrated and always available. The other three slots exist for backward
   compatibility; the new model treats tools as ordinary grid items found via
   `find_best_tool_for_action()`, which searches grid items by `PropDef.supports_actions`.

The separation is kept to avoid breaking existing callers. New content should favour placing
tools on the grid and querying via `find_best_tool_for_action`.

## Promises to content

### Grid placement

- **Shape is the primary spatial constraint.** Each item's footprint is its
  `PortableCap.slot_shape` rotated by the chosen orientation. Items with no `PortableCap`
  use a single-cell shape `[Vector2i(0,0)]`. A shape that does not fit anywhere in the grid
  is rejected.
- **`place_item(type) -> int` auto-places and returns the item_id.** Returns 0 on failure.
  Internally calls `find_placement(shape)` which tries all four rotations in row-major order
  and picks the first fit. Does not emit signals — callers that need signals should use
  `add_item(type, 1)` which wraps `place_item` with signal emission.
- **`place_item_at(type, origin, rotation) -> int` places at an explicit cell.** Returns 0
  if the shape (at that rotation) collides with any occupied cell or goes out of bounds.
- **`remove_item_by_id(item_id) -> bool` removes a specific instance.** Returns `false` if
  the id is unknown. Clears every cell the item occupied and emits `item_removed(type, 1)`
  and `inventory_changed`.
- **`move_item(item_id, new_origin, new_rotation) -> bool` is atomic.** Clears the old
  cells, checks the new placement (excluding the item's own cells via `exclude_id`), and
  either commits the move or rolls back to the original position. Returns `false` without
  side effects if the new placement is invalid.
- **`can_fit(shape, origin, rotation, exclude_id) -> bool` is a pure query.** Does not
  mutate state. `exclude_id` allows checking whether an item can move to a new position
  without treating its own current cells as blocked.
- **`find_placement(shape) -> Dictionary` returns `{origin, rotation}` or `{}`.** Tries
  rotations 0–3 in order; within each rotation scans cells in row-major order. Returns the
  first fit found. Returns an empty dict if no placement is possible in any orientation.
- **`get_item(item_id) -> Variant` returns item data or null.** Item data dict contains
  `{type, origin: Vector2i, rotation: int, shape: Array[Vector2i]}`.
- **`get_items_by_type(type) -> Array[int]` returns all item_ids of that type.** Empty array
  if none present.
- **`get_count(type) -> int` counts instances.** 0 if none.
- **`find_best_tool_for_action(action) -> int` returns an item_id or 0.** Searches grid
  items first (checking `PropDef.supports_actions` for `action`), then falls back to named
  tool slots. Returns 0 if nothing capable is found.

### Static shape utilities

- **`rotate_shape_once(shape) -> Array[Vector2i]`** — rotates a shape 90° clockwise.
- **`get_rotated_shape(base_shape, times) -> Array[Vector2i]`** — applies `rotate_shape_once`
  N times (N mod 4).
- **`get_shape_bounds(shape) -> Vector2i`** — returns the bounding box (width, height) of a
  shape as a `Vector2i`.

### Tool slots

- **`get_tool(slot)` returns `&""` if empty.** Querying an unknown slot also returns `&""`,
  never crashes.
- **`set_tool(slot, tool)` emits `tool_changed(slot, new_tool, old_tool)`.** Returns the
  previous tool id. Swapping tools does not interact with the grid — callers that want to
  return the old tool to the grid must do so themselves.
- **`has_tool_for(slot) -> bool`** — true if the slot is non-empty.

### Signals (all preserved)

- `inventory_changed()` — fired after any mutation.
- `item_added(type, amount)` — fired by `add_item` and `place_item*` on success.
- `item_removed(type, amount)` — fired by `remove_item*` variants on success.
- `inventory_full(type, rejected)` — fired when placement fails.
- `item_used(type)` — fired by `use_item`.
- `tool_changed(slot, new_tool, old_tool)` — fired by `set_tool`.

### Backward-compatible API

These methods preserve the call sites that existed before the grid model was introduced.
They behave correctly against the grid internally and should not be removed.

- **`add_item(type, amount) -> int`** — auto-places `amount` individual instances; returns
  the count actually placed. On partial failure emits `inventory_full(type, rejected)` once
  for the call, where `rejected` is the total number of instances that could not be placed.
- **`remove_item(type, amount) -> int`** — removes up to `amount` instances of `type`;
  returns count actually removed. Iterates `get_items_by_type(type)` and calls
  `remove_item_by_id` until `amount` is satisfied.
- **`has_item(type, amount) -> bool`** — true if `get_count(type) >= amount`.
- **`use_item(type) -> bool`** — removes one instance and emits `item_used(type)`. Returns
  `false` if none present.
- **`is_full() -> bool`** — true if no empty cell exists in the grid.
- **`get_slots() -> Array[Dictionary]`** — items grouped by type as `{type, quantity}`.
  RecipeRuntime and PredicateEvaluator use this.
- **`get_stacks() -> Array[Dictionary]`** — items grouped by type with cell-count size info
  as `{type, count, size_per_unit, total_size}`.
- **`expand(additional_rows)`** — appends rows to the grid; existing items are unaffected.
- **`capacity_size` property** — computed getter returns `grid_width * grid_height`; setter
  resizes the grid to the nearest integer row count. BuildingSystem writes this property
  directly (`inv.capacity_size += 50`); that contract is preserved.
- **`get_current_size()`, `get_capacity_size()`, `get_remaining_capacity()`,
  `get_size_display()`** — cell-count arithmetic helpers for UI display.
- **`get_max_slots()`, `get_used_slot_count()`** — slot-count arithmetic helpers.

### Save / load

- **New format:** `{grid_width, grid_height, items: [{id, type, origin: [x,y], rotation}], scanner}`.
- **Legacy migration:** On load, if the data contains a `slots` key (old format), each slot
  entry is replayed via `find_placement` to reconstruct a valid grid layout. Only the
  scanner entry is preserved from old `tools` dicts; the other tool slots are not migrated
  (tools are expected to be rediscovered as grid items).

## Requirements from content

- **Owned by Player, accessed via `player.get_inventory()`.** Every system walks up to the
  player and calls this method. Inventory is never an autoload.
- **PropRegistry must be initialised before any add/remove/query path runs.** Every type
  lookup goes through `PropRegistry.get_def(type)`. A type with no registered def is
  rejected from all placement methods (returns 0 or false). Content cannot add arbitrary
  StringNames — only registered PropDef ids.
- **`PortableCap.slot_shape` drives spatial footprint.** Items without a `PortableCap`
  default to a single-cell shape. Content authors must set `slot_shape` on any item that
  should occupy more than one cell.
- **Grid defaults.** `grid_width = 30`, `grid_height = 40`. Capacity can only grow via
  `expand` or by writing `capacity_size`.
- **RecipeRuntime** uses `add_item`, `remove_item`, `has_item`, `get_slots`.
- **AutoInteractionSystem** searches grid items for a weapon by checking
  `PropDef.tool_slot == &"weapon"`.
- **PredicateEvaluator** (`_eval_has_tool`) checks the scanner slot first, then falls back
  to `get_slots()` for other tools.
- **SurvivalSystem** uses `use_item`.
- **BuildingSystem** uses the `capacity_size` compat property.
- **InventoryPanel** subscribes to `inventory_changed` and `tool_changed`.
- **Player** calls `get_save_data()` / `load_save_data(data)`.

## Extension points

- **New tool slot.** Edit the `_tool_slots` dict literal. Save format, signal routing, and
  UI rows are driven off that dict.
- **New items.** Drop a new PropDef `.tres` with a `PortableCap` that has `slot_shape` set.
  Inventory accepts it as soon as PropRegistry scans it.
- **New capacity mechanic.** Any system can write `inv.capacity_size += N` or call
  `expand(rows)`. BuildingSystem does this for Storage Chest; a future upgrade tree can do
  the same.
- **Custom shapes.** `slot_shape` is just an `Array[Vector2i]`; L-shapes, T-shapes,
  irregular outlines all work. `rotate_shape_once` and `get_shape_bounds` are public for
  content tools that want to preview placements.
- **Panel integration.** InventoryPanel subscribes to `inventory_changed` and
  `tool_changed` and re-renders. Replacing the panel with a different UI only requires
  connecting those two signals. The contract is "tell me when something changed, I'll
  re-read."
- **Tests.** Because Inventory is a plain `RefCounted`, tests can construct one with
  `new()`, drive the API directly, and assert on the grid array. PropRegistry must be
  populated first (or the test doubles it).

## Genre-specific notes

Inventory is **survival-genre flavoured** with a **Tetris-style grid** that is more
distinctive than it first appears.

- **Shaped-item grid is survival/ARPG-genre iconic.** The 2D Tetris layout (Escape from
  Tarkov, Diablo, Path of Exile) communicates "space is precious" viscerally and makes
  item-management a tactile mini-game. The v1 model is a full implementation of this
  pattern.
- **No stacking is an intentional design choice.** Every prop instance is a discrete object
  on the grid. This favours scarcity, decision-making, and player agency over convenience.
  Games that want stacks would need a different model.
- **Tool slots as a separate namespace is survival-genre convention.** Separating "equipment
  I carry" from "resources I carry" prevents a full pouch from locking you out of your
  tools. The new model migrates toward tools-as-grid-items, but the named slots are kept to
  avoid breaking existing callers.
- **`find_best_tool_for_action` is the new equip model.** Rather than checking a specific
  slot, systems query for capability. This allows multi-tool items and future equipment
  diversity without adding new named slots.
- **Ground-drop-on-death is survival-flavoured.** Inventory does not own this logic — it
  lives in SurvivalSystem — but the cooperation between the two is genre-specific.
- **`expand` and `capacity_size` are Farhaven-specific progression hooks.** Placing a
  Storage Chest growing your grid is a concrete survival-game advancement mechanic. A
  pure-strategy game with unlimited resources would omit these.

A game that wants to replace Inventory outright must implement the same public API:
`add_item`, `remove_item`, `has_item`, `get_count`, `get_slots`, `is_full`, `get_max_slots`,
`get_used_slot_count`, `use_item`, `expand`, `get_tool`, `set_tool`, `has_tool_for`,
`place_item`, `place_item_at`, `remove_item_by_id`, `move_item`, `can_fit`,
`find_placement`, `get_item`, `get_items_by_type`, `find_best_tool_for_action`, plus the
full signal set above. Every consumer in the engine calls through this interface.

## Known limitations and TODOs

- **No sorting / auto-arrange.** Items are placed in the order they were picked up. A future
  pass could implement auto-consolidate or defragment to maximise free contiguous space.
- **No category tabs or visual grouping.** All grid items occupy one flat 2D space. Survival
  games with larger inventories typically group resources vs consumables in separate tabs.
- **`find_placement` is first-fit, not optimal-fit.** It returns the first valid position in
  row-major order across all four rotations. A best-fit or tightest-fit algorithm would
  reduce fragmentation at the cost of placement speed.
- **Legacy tool-slot migration is lossy.** When loading old save data, only the scanner is
  preserved from the old `tools` dict. Axe, pickaxe, and weapon must be re-found as grid
  items. This is intentional — the old named slots are being phased out — but it means old
  saves lose equipped tools on first load under the new system.
- **`capacity_size` setter rounds to nearest row.** Writing a non-multiple of `grid_width`
  truncates to the nearest whole row. Callers that write fractional increments may see
  unexpected grid sizes.
- **Grid shrink is not supported.** `expand` only adds rows. There is no shrink API. If
  `capacity_size` were written to a smaller value than the current grid, items in the
  removed rows would be silently lost. The compat setter guards against this by not
  shrinking below the current item footprint, but this is a live invariant that future
  changes must respect.
- **item_id monotonically increases and is never reused.** In very long sessions with
  frequent add/remove cycles this counter could theoretically overflow an `int32`. In
  practice Farhaven's item churn makes this unreachable, but it is worth noting for any
  future port to a 16-bit id scheme.
