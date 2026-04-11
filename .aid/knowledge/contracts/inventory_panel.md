# InventoryPanel

**Source:** `ui/inventory_panel.gd`
**Category:** engine-ui
**Layer:** ui
**Depends on:** [`inventory.md`](inventory.md), [`prop_def.md`](prop_def.md), [`catalog.md`](catalog.md) (optional, for future filtering). Embedded inside [`status_combined_panel.md`](status_combined_panel.md).

## What this system is

InventoryPanel is the **touch-first inventory drawer** — a `PanelContainer` rendering the
player's prop slots and tool slots. The player taps a prop slot to use/consume the item;
taps a tool slot to... (currently display only; tool-slot interaction is handled elsewhere).
It is the primary write-back surface for inventory from the UI side.

It has three sub-concerns:

1. **Slot rendering.** A grid of `InventorySlotUI` nodes, one per `Inventory._slots` entry.
   Refreshed on `inventory_changed`.
2. **Tool slot rendering.** A fixed row of four `ToolSlotUI` nodes for axe, pickaxe, weapon,
   scanner. Refreshed on `tool_changed`.
3. **Toxic flora confirmation.** A modal dialog when the player taps a consumable with
   `health_restore < 0`. Confirm → use; cancel → no-op.

## What it reads from the engine

- **`Inventory.get_slots() → Array[Dictionary]`.** Called during `_rebuild_slots` and
  `_refresh_all`. The returned array drives the slot grid population. Each dict has
  `type: StringName` and `quantity: int`.
- **`Inventory.get_max_slots() → int`.** Used on rebuild to decide how many slot widgets
  to create.
- **`Inventory.get_tool(slot_name) → StringName`.** Called during refresh for each of the
  four tool slots.
- **`Inventory.inventory_changed` signal.** Connected on `set_inventory`. Triggers
  `_refresh_all` when the panel is visible.
- **`Inventory.tool_changed(slot, new_tool, old_tool)` signal.** Connected on `set_inventory`.
  Updates the relevant tool slot widget when a tool is set/swapped/removed.
- **`PropDef.is_consumable` and `PropDef.health_restore`** (via `PropRegistry.get_def`).
  Used by `_is_toxic_flora` to decide if a tap should show the confirmation dialog. Toxic
  = consumable + negative health_restore.

## What it calls back to the engine

- **`Inventory.use_item(type)`** — the single write path. Called on slot tap after either
  no-confirmation (non-toxic items) or confirmed toxic intake. `use_item` itself removes
  one unit from the prop grid and emits `item_used(type)`, which SurvivalSystem subscribes
  to for stat application.

That's the entire engine write surface. InventoryPanel does not add items, does not move
items between slots, does not drop items, does not equip tools. All of those are either
engine-initiated (gather, death-drop) or player-initiated via systems other than this
panel (future: equip from tool slot UI).

## Contract with StatusCombinedPanel parent

- **`set_inventory(inv)` and `set_catalog(cat)`.** Dependency injection from the parent.
  `set_inventory` is required; `set_catalog` is currently optional and mostly unused
  (the toxic flora check reads PropDef directly — catalog reference is reserved for future
  per-species filtering).
- **`toggle()`, `open()`, `close()`** — standard panel lifecycle. StatusCombinedPanel's
  `_on_opened()` calls `_inventory_panel.open()` so tapping the STATUS button also opens
  inventory.
- **`panel_opened` signal** — emitted on open for mutual exclusion routing (used by
  CombinedPanel infrastructure even though InventoryPanel is now embedded rather than
  top-level).

## UI structure

- Header with title + close button
- Tool slots row (four horizontal ToolSlotUI widgets)
- Scrollable prop grid (GridContainer of InventorySlotUI widgets)
- ConfirmationDialog for toxic flora

The slot widget and tool slot widget are their own `ui/inventory_slot_ui.gd` and
`ui/tool_slot_ui.gd` files — not separately contracted here. They are pure rendering helpers
with a `refresh(slot)` / `refresh(tool_type)` method each.

## Genre-specific notes

- **Tap-to-use is touch-first survival convention.** A one-step consume for non-toxic food
  and a modal for toxic food is the Don't Starve model. A desktop game might use a drag-
  and-drop model or right-click contextual menu.
- **Four fixed tool slots are survival-genre convention.** Axe, pickaxe, weapon, scanner
  maps to the resource-gathering / exploration / self-defense triangle that defines
  Farhaven's core verbs. A different game would pick different tool categories (sword,
  shield, staff, focus in a fantasy RPG; primary, secondary, grenade, melee in a shooter).
- **Toxic flora confirmation is horror-flavoured.** The idea that some items are "scary to
  consume" is specific to survival/horror. A combat game would skip the confirmation and
  just let the player chug the potion.
- **Slot grid layout is a retro convention.** Minecraft-era inventory aesthetic. Works well
  for touch + small on-screen inventories. Would not scale to deep RPG inventories.
- **No drag-and-drop.** Every interaction is a single tap on a slot. Works for touch but
  locks out desktop UX conventions.

InventoryPanel's core shape (read Inventory, render slots, tap to use) is reusable for any
game with a pouch model. The parts that would need replacement for a different game are
the tool-slot row (different slot set), the toxic dialog (different special-case), and
the confirm-dialog pattern itself.

## Known limitations and TODOs

- **Catalog reference is effectively unused.** Set via `set_catalog` but only stored — the
  toxic check reads PropDef directly. A future "only show toxic warning for uncatalogued
  species" feature would need to wire up the catalog reference again.
- **No drag-and-drop.** Slot rearrangement, tool equip from inventory, item splitting —
  none of these exist in v1.
- **No inventory sort.** Slots stay in add order. A "consolidate same-type stacks" button
  would be a small win.
- **ConfirmationDialog text is hardcoded.** `"This item is toxic!\nConsume anyway?"`
  Needs localisation pass.
- **`_is_toxic_flora` name is misleading.** It's actually "is consumable with negative
  health delta" — applies to poisoned meat, spoiled berries, etc. not just flora. Rename
  pending cleanup.
- **Tool slot interaction is display-only.** Tapping a tool slot does nothing in v1.
  Equipping / unequipping tools happens elsewhere (e.g. during crafting or via a future
  radial menu).
- **No capacity indicator.** The size-based `capacity_size` from inventory is not rendered
  — the player has no UI feedback on "how full am I." Flagged as a missing v1 feature.
- **No per-slot hover tooltip.** Desktop users would expect a tooltip; not implemented.
- **Panel background style is hardcoded.** Same dark blue StyleBoxFlat as other panels —
  deliberate theme consistency, but not theme-driven.
