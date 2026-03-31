# Inventory

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F5/F12, §9 AC5 | /aid-interview |
| 2026-03-30 | Data Model written — separated tool slots + resource slots, auto-use tools | /aid-specify |
| 2026-03-30 | Data Model updated — 4 tool slots (added Scanner), use_item + item_used signal | /aid-specify |
| 2026-03-30 | Feature Flow + Layers & Components + UI Specs written | /aid-specify |
| 2026-03-31 | Audit fixes applied (see delivery DETAIL.md) | /audit |

## Source

- REQUIREMENTS.md §5 F5 (Inventory)
- REQUIREMENTS.md §5 F12 (HUD Layout — inventory button)
- REQUIREMENTS.md §9 AC5 (Inventory acceptance criteria)
- REQUIREMENTS.md §10 P0 — Core Loop

## Description

The player has a grid-based inventory starting with ~12 slots. Items stack with quantity display. When the inventory is full, picking up a new item is rejected with visual feedback. Inventory can be expanded by building a Storage Chest (+12 slots per chest). The inventory is accessed via a button in the bottom-right HUD. The HUD is minimal and translucent — screen is the game, not the UI.

## User Stories

- As a player, I want to see what I've gathered in a clear grid so I know what I have
- As a player, I want items to stack so my limited inventory isn't wasted on duplicates
- As a player, I want to expand my inventory by building storage so I can carry more as I progress

## Priority

Must (P0 — Core Loop)

## Acceptance Criteria

- [ ] Start with 12 empty slots
- [ ] Pick up 13th unique item without Storage Chest → rejected with feedback
- [ ] Build Storage Chest → inventory expands to 24 slots
- [ ] Items stack with quantity display

## Save Integration

Adds inventory contents (item types, quantities, slot positions) to save data.

---

## Technical Specification

### Data Model

#### Inventory (RefCounted)

The inventory is runtime state owned by the Player node. Not a Godot Resource — serialized
to JSON manually. RefCounted keeps it lightweight with no scene tree overhead.

Two separate storage systems:

1. **Resource/consumable slots** — grid-based, expandable, stackable
2. **Tool slots** — 4 fixed slots, one tool each, auto-used, upgrade replaces in-place

```gdscript
# Resource/consumable storage
var _slots: Array[Dictionary]         # length = _max_slots
var _base_slots: int = 12             # constant
var _bonus_slots: int = 0             # from Storage Chests (+12 each)
# _max_slots computed as _base_slots + _bonus_slots

# Tool storage — 4 fixed slots, separate from inventory grid
var _tool_slots: Dictionary = {
    &"axe": &"",                      # empty at start
    &"pickaxe": &"",                  # empty at start
    &"weapon": &"survival_knife",     # starter weapon
    &"scanner": &"scanner",            # starter scanner — functionality is future work
}
```

**Starting state:** 12 empty resource slots. Axe empty, Pickaxe empty, Weapon = Survival Knife, Scanner = Scanner.

#### Inventory Slot (Dictionary)

Each resource/consumable slot:

```gdscript
{ "type": StringName, "quantity": int }
# &"" / 0 = empty slot
```

Tools never enter the `_slots` array. Resources never enter `_tool_slots`.

#### Stacking Rules

- Resources stack to a per-type maximum (e.g., wood → 99, berries → 20).
- Stack limits come from the item config table.
- `add_item` finds an existing partial stack first, then uses an empty slot.
- Tools cannot be added to resource slots — routed to tool slots via `set_tool`.

#### Item Config Table

```gdscript
# item_config: Dictionary[StringName, Dictionary]
{
  # Resources
  &"wood":           { "max_stack": 99, "category": &"resource" },
  &"stone":          { "max_stack": 99, "category": &"resource" },
  &"berries":        { "max_stack": 20, "category": &"consumable" },
  &"fiber":          { "max_stack": 99, "category": &"resource" },
  &"ore":            { "max_stack": 99, "category": &"resource" },
  &"crystal":        { "max_stack": 50, "category": &"resource" },

  # Tools — tool_slot instead of max_stack
  &"stone_axe":      { "tool_slot": &"axe",     "category": &"tool" },
  &"stone_pickaxe":  { "tool_slot": &"pickaxe",  "category": &"tool" },
  &"survival_knife": { "tool_slot": &"weapon",   "category": &"tool" },
  &"scanner":        { "tool_slot": &"scanner",  "category": &"tool" },
}
```

`category` is informational for UI display. `tool_slot` routes the item to the correct
fixed slot. Resources have `max_stack`; tools have `tool_slot` — mutually exclusive.

#### Public API — Resource/Consumable Slots

```gdscript
# Add resources — returns amount actually added (less if full)
func add_item(type: StringName, amount: int = 1) -> int

# Remove resources — returns amount actually removed (less if not enough)
func remove_item(type: StringName, amount: int = 1) -> int

# Queries
func has_item(type: StringName, amount: int = 1) -> bool
func get_count(type: StringName) -> int         # total across all slots
func get_slots() -> Array[Dictionary]            # for UI rendering (read-only copy)
func is_full() -> bool                           # no empty slots AND no partial stacks
func get_max_slots() -> int
func get_used_slot_count() -> int

# Use consumable — removes 1 and emits item_used for downstream features
func use_item(type: StringName) -> bool          # false if not in inventory

# Capacity expansion (called when Storage Chest built)
func expand(additional_slots: int) -> void
```

**`add_item` logic:**
1. Check `item_config[type]` — if it has `tool_slot`, reject (tools use `set_tool`)
2. Find existing slot with matching type AND `quantity < max_stack` → fill it
3. If remainder: find first empty slot → create new stack
4. If still remainder: emit `inventory_full`, return amount not added

#### Public API — Tool Slots

```gdscript
# Get tool in a slot (returns &"" if empty)
func get_tool(slot: StringName) -> StringName

# Set tool in slot — returns previous tool (for crafting to know what was replaced)
# Previous tool is discarded (gone), not returned to inventory
func set_tool(slot: StringName, tool: StringName) -> StringName

# Convenience — does the player have any tool in this slot? (convenience API)
func has_tool_for(slot: StringName) -> bool
```

**Tool upgrade flow:** Crafting a Stone Axe → `inventory.set_tool(&"axe", &"stone_axe")`.
Returns `&""` (was empty) or the previous tool name (replaced). Old tool is gone — no
salvage, no refund. One tool per slot, always.

**Gather system integration:** Feature-003's `can_gather` checks
`inventory.get_tool(&"axe") == &"stone_axe"` (or similar). No `Player.equipped_tool`
property. Tools are auto-used — if the player has a Stone Axe in the axe slot, it's
used automatically when chopping.

#### Signals

```gdscript
signal inventory_changed()                               # any add/remove/expand
signal item_added(type: StringName, amount: int)         # resource added
signal item_removed(type: StringName, amount: int)       # resource removed
signal inventory_full(type: StringName, rejected: int)   # couldn't fit everything
signal item_used(type: StringName)                       # consumable used (tap in UI)
signal tool_changed(slot: StringName, new_tool: StringName, old_tool: StringName)
```

#### Save Data

```json
{
  "inventory": {
    "bonus_slots": 12,
    "tools": {
      "axe": "stone_axe",
      "pickaxe": "",
      "weapon": "survival_knife",
      "scanner": "scanner"
    },
    "slots": [
      { "type": "wood", "quantity": 15 },
      { "type": "stone", "quantity": 8 },
      { "type": "", "quantity": 0 },
      ...
    ]
  }
}
```

Slots saved in order (position matters for UI). `_base_slots` is constant (not saved),
`_bonus_slots` is saved, `_max_slots` derived on load. Tool slots saved separately.

### Feature Flow

#### Add Resource (from gathering)

```
Inventory.add_item(&"wood", 1)
  │
  ├─ item_config[&"wood"] has max_stack → resource path
  ├─ Find existing &"wood" slot with quantity < 99 → increment
  ├─ Else find empty slot → create new stack
  ├─ Else → emit inventory_full, return 0
  ├─ Emit item_added + inventory_changed
  └─ Return amount added
```

#### Add Tool (from crafting)

```
Inventory.set_tool(&"axe", &"stone_axe")
  │
  ├─ old = _tool_slots[&"axe"]  → &"" or previous tool
  ├─ _tool_slots[&"axe"] = &"stone_axe"
  ├─ Emit tool_changed(&"axe", &"stone_axe", old)
  ├─ Emit inventory_changed
  └─ Return old (discarded — no salvage)
```

#### Remove Resource (from crafting/building)

```
Inventory.remove_item(&"wood", 5)
  │
  ├─ Scan _slots reverse order — decrement from last partial stacks first
  ├─ Clear empty slots (type = &"", quantity = 0)
  ├─ Emit item_removed + inventory_changed
  └─ Return amount removed
```

Reverse-order consumption minimizes fragmentation — empties recent stacks first, keeps
lower slots stable for the player's visual layout.

#### Use Consumable (from inventory UI)

```
Player taps berries in inventory panel
  │
  ├─ Inventory UI calls Inventory.use_item(&"berries")
  │
  ├─ Check has_item(&"berries") → false? return false, do nothing
  │
  ├─ remove_item(&"berries", 1)
  ├─ Emit item_used(&"berries")
  │     → Feature-006 (survival stats) listens: apply hunger/thirst restore
  ├─ Emit inventory_changed
  └─ Return true
```

**Ownership split:** Inventory owns the trigger (tap consumable → remove → emit signal).
Feature-006 owns the effect (what eating berries does to stats). Inventory doesn't know
about hunger/thirst — it just says "berries were used." This keeps the features decoupled.

#### Expand Capacity (Storage Chest built)

```
Building system calls Inventory.expand(12)
  │
  ├─ _bonus_slots += 12
  ├─ Append 12 empty slots to _slots
  ├─ Emit inventory_changed
  └─ UI renders additional slots
```

Multiple Storage Chests stack: each adds +12. No cap in MVP.

#### Inventory Full — Rejection

When `add_item` can't fit:
- `inventory_full` signal emits with type and rejected amount
- Resource is lost (not dropped on ground — that's future work)
- UI shows brief "Inventory Full" feedback

### Layers & Components

#### Scene Tree Additions

```
Main (Node)
  └─ World (Node3D)                             [existing]
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ ResourceRenderer (Node3D)             [feature-003]
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)
       │    └─ GatherSystem (Node)              [feature-003]
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ GatherFeedback (CanvasLayer)               [feature-003]
  └─ HUD (CanvasLayer)                          ← NEW
       ├─ InventoryButton (TextureButton)       ← NEW (bottom-right)
       └─ InventoryPanel (PanelContainer)       ← NEW (bottom drawer, hidden by default)
            ├─ ToolSlotsRow (HBoxContainer)     ← 4 fixed tool slots at top
            └─ ScrollContainer                  ← always scrollable
                 └─ ResourceGrid (GridContainer) ← 12+ resource slots
```

#### File Structure

```
scripts/
  inventory/
    inventory.gd            # RefCounted — data + API + signals (owned by Player)

scenes/
  ui/
    hud.tscn                # CanvasLayer — HUD container (inventory button, future: stat bars)
    inventory_panel.tscn    # PanelContainer — the inventory overlay

ui/
  inventory_panel.gd        # Control — inventory UI logic (open/close, slot rendering)
  inventory_slot_ui.gd      # Control — single slot display (icon, quantity, tap handler)
  tool_slot_ui.gd           # Control — single tool slot display (icon, slot label)

data/
  item_config.tres          # Resource — max_stack, category, tool_slot per item type
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `inventory.gd` | RefCounted owned by Player. All data, API, signals. No scene tree. No UI. | `item_config.tres` (stack limits, categories) |
| `inventory_panel.gd` | Control script on InventoryPanel. Reads `inventory.get_slots()` and tool slots to render. Handles tap-on-slot for consumable use. Open/close toggle. | `Inventory` (API + signals) |
| `inventory_slot_ui.gd` | Individual slot Control. Shows item icon + quantity label. Tap handler: if consumable → call `inventory.use_item()`. | `Inventory` (use_item), `item_config` (category check) |
| `tool_slot_ui.gd` | Individual tool slot Control. Shows tool icon + slot label (&"Axe", &"Pickaxe", etc.). No tap interaction — tools are auto-used. | `Inventory` (get_tool) |

#### Signal Wiring

```
Inventory signals                        inventory_panel.gd
  inventory_changed()                ──►  re-render all slots
  tool_changed(slot, new, old)       ──►  update specific tool slot UI

Inventory signals                        gather_feedback.gd / building / crafting
  inventory_full(type, rejected)     ──►  show "Inventory Full" feedback

Inventory signals                        feature-006 (survival stats)
  item_used(type)                    ──►  apply stat effect (berries → hunger restore)

inventory_panel.gd
  signal panel_toggled(visible)      ──►  no pause — game continues running underneath
```

#### Inventory Panel — Open/Close

- **Open:** Tap InventoryButton (bottom-right HUD) → drawer slides up from bottom.
  Game continues running — no pause. Upper ~55% of screen shows the game world.
- **Close:** Tap InventoryButton again, tap X on panel, or tap the visible game area above.
- Panel reads `inventory.get_slots()` + `inventory.get_tool()` for each slot on open and
  on `inventory_changed` signal.

#### HUD Integration

InventoryButton is part of the HUD CanvasLayer. This is the first HUD element in the
game — future features add more (stat bars for feature-006, build/craft buttons for
feature-005/008, day counter for feature-007). The HUD CanvasLayer is created here and
shared.

### UI Specs

#### Layout — Portrait 1080x1920

```
┌──────────────────────────┐
│  [HP] [Hunger] [Thirst]  │  ← future (feature-006)
│              Day 7 ☀     │  ← future (feature-007)
│                          │
│      (game world visible)│  ← ~55% of screen, game runs
│                          │
│                          │
├──────────────────────────┤  ← drawer top edge, drag handle
│  INVENTORY           [X] │  ← header + close
│ [Axe] [Pick] [Wpn] [Scn]│  ← 4 tool slots (fixed row)
│ ─────────────────────────│
│ [1] [2] [3]              │  ← resource grid (3 columns)
│ [4] [5] [6]    scrollable│  ← ScrollContainer always
│ [7] [8] [9]              │
│ [10][11][12]             │  ← ~45% of screen height
└──────────────────────────┘
```

#### Inventory Panel — Bottom Drawer

- **PanelContainer** — full-width bottom drawer that slides up from bottom edge
- Width: 100% screen width. Height: ~45% screen height (~864px at 1920).
  Upper ~55% of screen remains visible — player can see the game world.
- Semi-transparent background
- Drag handle at top for feel (visual only — open/close via button tap for MVP)
- Header row: "Inventory" label + close button (X)
- Tool slots row: **HBoxContainer**, 4 slots in a row, labeled (Axe, Pickaxe, Weapon, Scanner)
- Resource grid: **ScrollContainer** wrapping **GridContainer**, 3 columns.
  ScrollContainer is always present — not a fallback for large inventories.
  Scroll is the default layout from day one.
- Game continues running while panel is open. No pause.

#### Slot Design

Each slot is a **TextureRect + Label** in a **PanelContainer**:

```
┌──────────┐
│  [icon]  │   ← item icon (placeholder: colored square per type)
│    x15   │   ← quantity label (bottom-right, hidden if quantity = 1 or tool)
└──────────┘
```

- **Size:** ~90x90px at 1080 width, 3 columns = 270px + spacing. Above 48dp min touch target.
- **Empty slot:** faded border, no icon, no label.
- **Consumable slot:** tap → `inventory.use_item(type)`. Brief highlight animation on use.
- **Resource slot (non-consumable):** tap does nothing (informational only).
- **Tool slot:** shows tool icon + slot label below. No tap interaction. Empty = "—" or empty icon.

#### Touch Targets

- Slot size ~90x90px → well above 48dp minimum
- Close button: 48x48px minimum
- InventoryButton (HUD): 64x64px
- Spacing between slots: 8-12px to prevent mis-taps

#### Accessibility (MVP)

- High contrast between slot background and item icons
- Quantity text uses readable font size (min 24px at 1080 width)
- Empty vs occupied slots visually distinct (not just color — border style differs)
