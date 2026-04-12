# delivery-006f: Grid-based Tetris Inventory

**Status:** Planning
**Created:** 2026-04-12
**Depends on:** delivery-006d (merged to main — engine stabilization docs + tests + BDD)
**Relation to delivery-006e (Combat):** Isolated. Both can run in parallel; packing shapes don't depend on combat runtime. When combat lands, weapons inherit whatever slot shape they're authored with.
**Cumulative state:** Inventory becomes a 2D grid. Every storable prop has a shape. Player bag is 30×40 cells. Items fit like sprite tetris. Containers (chests) also use grid shapes. No `size: float` field — shape is the spatial unit.

> **Design rationale:** Replace the current `PortableCap.size: float` abstraction with explicit 2D shapes. Each prop occupies a specific set of cells in the bag grid. The player packs their backpack like a workshop — axes, pickaxes, knives, and bows take bulky bespoke shapes; berries and arrows slot into the gaps. The result is a **spatial decision** about what to carry, rendered as a visible silhouette collage.

## Key design decisions (pinned from 2026-04-12 design conversation)

| # | Decision | Value |
|---|----------|-------|
| 1 | Cap naming | Keep `PortableCap` (no rename) — just gains a `slot_shape` field |
| 2 | `ContainerCap` grid shape | `grid_width: int × grid_height: int` rectangular |
| 3 | Player backpack starter | **30 wide × 40 tall = 1200 cells** |
| 4 | UI cell size | **10×10 px** → full backpack renders at ~300×400 px |
| 5 | Item shapes | **Irregular (L, T, blob, line)**, authored as `Array[Vector2i]` of cells relative to item origin |
| 6 | Rotation | **90° only** (4 orientations), player-triggered via hotkey |
| 7 | Stacking | **No stacking.** 1 prop = 1 shape. 100 berries = 100 cells in the bag (each berry is 1 cell) |
| 8 | Tool size proportion | Close to **10-15% per big tool** (bag-II proportion) — decided item-by-item during content migration |
| 9 | Scanner | Body-integrated, NOT a bag item, NOT a slot shape |
| 10 | Tool invocation | Tools are auto-used from the bag when an action fires (tools-as-invoked), no "equipped slot" concept |

## Engine inventory impact

**Files that change fundamentally:**
- `scripts/data/capabilities/portable_cap.gd` — replace `size: float` with `slot_shape: Array[Vector2i]`
- `scripts/data/capabilities/container_cap.gd` — replace `capacity_size: float` with `grid_width: int, grid_height: int`
- `scripts/inventory/inventory.gd` — complete rewrite of storage model from size-count to grid-pack
- `ui/inventory_panel.gd` + `ui/inventory_slot_ui.gd` — rewrite from list layout to grid layout with shape rendering
- `tools/level-editor/js/prop-editor.js` — add shape authoring tool (draw-on-grid pixel editor)
- All `data/props/*.tres` files with PortableCap — migrate `size` → `slot_shape`
- All `data/props/*.tres` files with ContainerCap — migrate `capacity_size` → `grid_width`/`grid_height`

**Files that change slightly:**
- `scripts/auto_interaction/auto_interaction_system.gd` — `find_best_tool_for_action()` helper
- `scripts/recipes/recipe_runtime.gd` — input consumption from grid instead of stack count
- Save/load schema — inventory grid state

## Tasks

| # | Name | Type | Est. hours |
|---|------|------|-----------|
| 089 | PortableCap `slot_shape` + ContainerCap `grid_width/height` data model | IMPLEMENT | 2 |
| 090 | Inventory grid engine: placement algorithm, rotation, fit-check | IMPLEMENT | 6 |
| 091 | Inventory save/load for grid state + rotation | IMPLEMENT | 2 |
| 092 | InventoryPanel UI: grid render, cell highlighting, item shape sprites | IMPLEMENT | 5 |
| 093 | InventoryPanel UI: drag-and-drop, rotation hotkey, invalid placement feedback | IMPLEMENT | 4 |
| 094 | Editor: shape authoring tool for PropDef (draw-on-grid pixel editor) | IMPLEMENT | 4 |
| 095 | Content migration: assign shapes to all existing props (berries, wood, stones, tools, weapons, etc.) | CONTENT | 3 |
| 096 | AutoInteractionSystem: `find_best_tool_for_action()` + `supports_actions` on PropDef | IMPLEMENT | 2 |
| 097 | RecipeRuntime: consume inputs from grid instead of stack count | REFACTOR | 2 |
| 098 | Unit tests: Inventory grid engine (placement, rotation, edge cases, save/load) | TEST | 3 |
| 099 | BDD: tetris inventory integration scenarios (pack/unpack, rotation, overflow, tool invocation) | TEST | 3 |
| 100 | Editor round-trip tests: shape authoring, shape preservation through save | TEST | 2 |
| 101 | Contract doc updates (portable_cap.md, container_cap.md, inventory.md) | DOCS | 1 |

**Estimated total: ~39 hours**

---

## Task Details

### task-089: PortableCap + ContainerCap data model

**PortableCap** gains a `slot_shape: Array[Vector2i]` field. Each Vector2i is a cell offset relative to the item's origin (0,0). Example shapes:

- **Berry** (1 cell): `[Vector2i(0,0)]`
- **Stick** (3×1 line): `[(0,0), (1,0), (2,0)]`
- **Wood** (2×1 line): `[(0,0), (1,0)]`
- **Stone** (2×2 blob): `[(0,0), (1,0), (0,1), (1,1)]`
- **Log** (4×2 rectangle): `[(0,0), (1,0), (2,0), (3,0), (0,1), (1,1), (2,1), (3,1)]`
- **Knife** (4×2 L, ~6 cells): `[(0,0), (1,0), (2,0), (3,0), (3,1), (2,1)]` — blade + handle
- **Axe** (~6×10 L-shape, ~20-30 cells) — handle column + head on top
- **Pickaxe** (~6×12 L-shape, ~30 cells) — longer handle, head at top
- **Bow** (~2×15 curved line, ~20-25 cells) — long vertical
- **Gun** (~5×4 L, ~12-15 cells) — grip + barrel

Actual cell counts to be refined in task-095 (content migration).

**ContainerCap** replaces `capacity_size: float` with:
- `grid_width: int` (default: 30 for player backpack)
- `grid_height: int` (default: 40 for player backpack)
- Chests will have smaller grids (6×4? 8×6?) — authored per PropDef

**Backward compatibility:** breaking change. All existing .tres files must be migrated in task-095.

**Deliverable:** Updated cap .gd files + migration scaffolding (not all .tres files yet — that's 095).

---

### task-090: Inventory grid engine

Rewrite `scripts/inventory/inventory.gd` around a 2D grid model.

**Core data:**
- `_grid: Array[Array[int]]` — 2D array, `grid_width × grid_height`. Each cell stores an item instance ID (0 = empty, >0 = item_id).
- `_items: Dictionary[int, Dictionary]` — item_id → `{type: StringName, origin: Vector2i, rotation: int, shape: Array[Vector2i]}`
- `_next_id: int` — monotonically increasing instance id

**Core operations:**
- `can_fit(shape: Array[Vector2i], origin: Vector2i, rotation: int) -> bool` — check every cell of the rotated shape against the grid
- `find_placement(shape: Array[Vector2i]) -> Dictionary` — first-fit search: iterate grid origins, iterate rotations, return `{origin, rotation}` or `null`
- `add_item(type: StringName) -> int` — find placement, write cells, return item_id (or 0 if no fit)
- `add_item_at(type: StringName, origin: Vector2i, rotation: int) -> int` — explicit placement, used for load/drag-drop
- `remove_item(item_id: int) -> bool` — free cells
- `move_item(item_id: int, new_origin: Vector2i, new_rotation: int) -> bool` — remove + re-add atomically; fails if new placement doesn't fit
- `get_items_by_type(type: StringName) -> Array[int]` — list instance ids of a given type
- `get_count(type: StringName) -> int` — count of instances of a type (for compatibility with gather/recipe checks)
- `find_best_tool_for_action(action: StringName) -> int` — scan items, return the first one whose PropDef has `supports_actions.has(action)` (priority tie-breaker later)

**Rotation semantics:** rotating a shape by 90° rotates each cell offset: `(x, y) → (-y, x)` then translate to positive quadrant. Store the 4 pre-computed rotated shapes on the item instance.

**Algorithm performance:** 30×40 grid, 4 rotations, shape with ~20 cells → worst case `1200 × 4 × 20 = 96000` checks per placement. Negligible.

**Deliverable:** Fully rewritten `inventory.gd` with the new API + backward-compat stubs for `add_item(type, amount)` (calls `add_item(type)` in a loop).

---

### task-091: Save/load grid state

Inventory save data changes shape:

```json
{
  "grid_width": 30,
  "grid_height": 40,
  "items": [
    {"id": 1, "type": "P00010", "origin": [0, 0], "rotation": 0},
    {"id": 2, "type": "P00204", "origin": [5, 3], "rotation": 90},
    ...
  ],
  "tool_slots": { ... }  // tool_slot field stays for now, see open question below
}
```

On load: clear grid, iterate items, call `add_item_at(type, origin, rotation)` for each. Skip items whose shape no longer fits (defensive — schema change should have migrated first).

**Deliverable:** save/load round-trip on the grid.

---

### task-092: InventoryPanel grid render

Rewrite `ui/inventory_panel.gd` around a 2D grid panel.

- Root is a `Control` of size `grid_width * cell_size × grid_height * cell_size` (300×400 at 30×40×10px)
- Grid background: draw cell borders (1px lines)
- Items rendered as colored silhouettes of their shape (use PropDef's `placeholder_color` for fill)
- Selected item highlighted (border + tint)
- Hover shows item tooltip with name + description

**Deliverable:** Visual-only grid panel. No interaction yet (that's 093).

---

### task-093: Drag-and-drop, rotation, invalid placement

Interaction layer for the grid panel.

- **Click + drag** an item: picks it up (remove from grid visually, ghost follows cursor)
- **R key while dragging:** rotates the held item 90°
- **Release over valid placement:** places item
- **Release over invalid placement (overlap):** snaps back to original position, red flash
- **Invalid preview while hovering:** ghost renders red where overlap would occur
- **Drop outside grid:** snap back (or later, drop to ground — future scope)

**Deliverable:** Full interaction loop, controller-friendly later.

---

### task-094: Editor shape authoring tool

Add a shape picker to the PropEditor in `tools/level-editor/`.

- A small grid (e.g., 10×10) with cells the author can click to toggle on/off
- Cells "on" form the item's shape
- Preview the rotated orientations
- Origin indicator (where (0,0) is — usually top-left of the bounding box)
- Save button writes `slot_shape` into the PropDef .tres file

**Deliverable:** Shape authoring in the editor + round-trip tests.

---

### task-095: Content migration

Every prop with PortableCap gets a shape. Every prop with ContainerCap gets a grid size.

**Small consumables (berry, mushroom, seed):** 1 cell.

**Medium resources (wood, stone, stick):** 2-4 cells.

**Large resources (log, boulder):** 6-12 cells.

**Tools — authored with character:**
- Knife ~6-8 cells (small L)
- Axe ~20-30 cells (handle + head L)
- Pickaxe ~30-40 cells (longer handle + head L)
- Bow ~20-25 cells (vertical line slightly curved)
- Gun ~12-15 cells (grip + barrel L)
- Torch ~6-10 cells (short stick)
- Firestarter ~2 cells (small)

**Containers:**
- Player backpack: 30×40 (default)
- Storage chest: 15×15 (starter chest)
- Small pouch: 6×6 (pocket-sized)

**Deliverable:** All existing `data/props/*.tres` files migrated. Old `size` field removed. Old `capacity_size` field removed.

---

### task-096: AutoInteractionSystem integration

Update `scripts/auto_interaction/auto_interaction_system.gd`:

- Add `PropDef.supports_actions: Array[StringName]` — actions the prop can perform when used as a tool (e.g., `[&"chop"]` for axe, `[&"mine"]` for pickaxe, `[&"attack_melee"]` for knife).
- When auto-gather triggers, look up the action needed by the target prop (`PropDef.gather_action` or similar — may reuse recipe actions), then call `inventory.find_best_tool_for_action(action)` to get the tool instance.
- If no matching tool, emit `auto_gather_failed(&"tool_required")` as before.

**Deliverable:** Auto-use matches the right tool from bag contents.

---

### task-097: RecipeRuntime grid-aware input consumption

`RecipeRuntime._consume_from_player_vicinity` and `_consume_from_inventory` currently use stack count logic. Update to use grid-based item instance removal:

- `Inventory.get_count(type)` returns instance count, not stack size
- `Inventory.remove_item_by_type(type, count)` removes N instances, freeing their cells

**Deliverable:** Recipes work end-to-end with grid inventory.

---

### task-098: Unit tests — grid engine

Cover in `tests/unit/test_inventory_grid.gd`:

- Empty grid construction
- Placement of a 1-cell item
- Placement of a 2×1 item in empty grid
- Placement of an L-shape in empty grid
- Rotation (4 orientations of an L-shape)
- Placement fails when overlap
- First-fit search finds the corner when grid is mostly full
- Remove item frees cells
- Save/load round trip
- `find_best_tool_for_action` returns the right item

~20-30 test cases.

---

### task-099: BDD — tetris inventory flows

`tests/features/tetris_inventory.feature`:

- Pick up an axe → fits in empty bag
- Pick up a second axe → also fits (if room)
- Pick up 100 berries → each berry takes a cell, bag fills gradually
- Pick up an item that doesn't fit → rejection signal
- Rotate a rectangular item, re-check fit
- Auto-use finds the axe for chop action
- Auto-use returns "no tool" when axe not in bag

~10-15 scenarios.

---

### task-100: Editor round-trip

`tools/level-editor/test-unit.mjs`:

- Round-trip a PropDef with an L-shape through editor save/load
- Round-trip a ContainerCap with custom grid size
- Shape authoring UI state (cell toggle, rotation preview)

---

### task-101: Contract doc updates

- `portable_cap.md` — update field description, add shape authoring notes, add genre-specific notes about the tetris design
- `container_cap.md` — document grid_width/height replacement
- `inventory.md` — rewrite the data model section for grid

---

## Open questions

### Q1: Tool slot fields — keep or remove?

The current Inventory has `_tool_slots: Dictionary = { axe: "", pickaxe: "", weapon: "", scanner: "" }`. In the tetris model, **tools live in the grid, not in tool slots.** Should we:

- **(a)** Remove `_tool_slots` entirely — tools are just items in the bag, `find_best_tool_for_action` does the work
- **(b)** Keep `_tool_slots` as a cache/pin — player can "favorite" a tool to the quick-access set, even though it still occupies grid cells
- **(c)** Keep `_tool_slots` only for the scanner (body-integrated) and remove the rest

**Recommendation:** **(c)** — scanner is body-integrated so it stays outside the grid. All other tools go in the grid. This preserves the design principle "scanner is body, tools are bag" and lets us delete the tool_slot enum complication.

### Q2: Rotation pivot

When a player rotates an L-shape, does it rotate around:
- The top-left cell (origin stays fixed)?
- The geometric center (visually "spins in place")?

**Recommendation:** Origin stays fixed (simpler math, player sees origin move but can re-grab to reposition).

### Q3: Multi-cell items overlapping with ground/tile loot

When an axe drops on a tile, does it occupy ground space as a shape? Or is ground loot just a list?

**Recommendation:** Ground is a list (current behavior). Shape only matters inside containers. Pickup promotes list item into shape when it enters a bag.

### Q4: Backpack upgrade path

How does the player increase bag capacity over the game? Current Inventory has `expand(n)` for slot count. In grid mode:
- Expand columns? Rows?
- Swap backpack for a bigger one?
- Specific "add row" powerup?

**Recommendation:** Defer to delivery-007 content. For now, bag is 30×40 fixed.

---

## Exit criteria

- [ ] PortableCap and ContainerCap migrated to shape/grid fields
- [ ] Inventory grid engine passes all unit tests
- [ ] InventoryPanel renders grid with drag-and-drop and rotation
- [ ] Editor supports shape authoring
- [ ] All existing props migrated to shapes
- [ ] Recipes consume grid inventory correctly
- [ ] BDD scenarios cover the tetris flows
- [ ] Contract docs updated
- [ ] Andre plays with the new inventory and says "sim, é isso"

---

## Relationship to delivery-006e (Combat)

delivery-006e adds combat runtime (weapons dealing damage, EnduranceCap applying multipliers). Weapons are **just tools with `supports_actions = [&"attack_*"]`**. Their grid shapes are authored in task-095 regardless of combat status — so 006f can ship standalone without combat existing. When combat lands, it invokes weapons via the same `find_best_tool_for_action(&"attack_melee")` path.

Both deliveries are independent in code. Order is up to Andre. Suggested: **006f first** so combat weapons inherit the new shape model natively rather than being retrofitted.
