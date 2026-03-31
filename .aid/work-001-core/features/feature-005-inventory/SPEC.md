# Inventory

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Feature identified from REQUIREMENTS.md §5 F5, §9 AC5 | /aid-interview |
| 2026-03-31 | Full technical specification — all sections | /aid-specify |
| 2026-03-31 | Fixes: add_item at arrival not start, 5-panel mutual exclusion list | /aid-specify |

## Source

- REQUIREMENTS.md §5 F5 (Inventory)
- REQUIREMENTS.md §9 AC5 (Inventory acceptance criteria)

## Description

The player has a grid-based inventory with ~12 resource/consumable slots and 4 fixed tool slots (Axe, Pickaxe, Weapon, Scanner). Items stack with quantity display. Tools are auto-used -- no manual equip/unequip. Consumables can be used by tapping in the inventory panel (with scan-safety check for unknown flora). Inventory expands by building Storage Chests (+12 slots each).

## User Stories

- As a player, I want to see what I've gathered in a clear grid
- As a player, I want items to stack so my limited slots aren't wasted
- As a player, I want to expand my storage by building

## Priority

Must (P0 -- Core Loop)

## Acceptance Criteria

- [ ] Start with 12 empty resource slots + 4 tool slots
- [ ] Auto-pickup 13th unique item without Storage Chest -> rejected with feedback
- [ ] Build Storage Chest -> inventory expands to 24 resource slots
- [ ] Items stack with quantity display

## Save Integration

Inventory slots (type, quantity, position), tool slots, bonus_slots count.

---

## Technical Specification

### Data Model

#### Inventory (RefCounted)

Runtime state owned by the Player node. Not a Godot Resource — serialized to JSON
manually. RefCounted keeps it lightweight with no scene tree overhead.

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
    &"scanner": &"scanner",           # starter scanner
}
```

**Starting state:** 12 empty resource slots. Axe empty, Pickaxe empty,
Weapon = Survival Knife, Scanner = Scanner.

#### Inventory Slot (Dictionary)

```gdscript
{ "type": StringName, "quantity": int }
# &"" / 0 = empty slot
```

Tools never enter `_slots`. Resources never enter `_tool_slots`.

#### Stacking Rules

- Resources stack to a per-type max from item_config (e.g., wood → 99, berries → 20)
- `add_item` finds existing partial stack first, then empty slot
- Tools cannot be added to resource slots — routed via `set_tool`

#### Item Config Table

```gdscript
# item_config: Dictionary[StringName, Dictionary]
{
  # Resources
  &"wood":           { "max_stack": 99, "category": &"resource" },
  &"stone":          { "max_stack": 99, "category": &"resource" },
  &"berries":        { "max_stack": 20, "category": &"consumable" },
  &"toxic_berries":  { "max_stack": 20, "category": &"consumable" },
  &"fiber":          { "max_stack": 99, "category": &"resource" },
  &"ore":            { "max_stack": 99, "category": &"resource" },
  &"crystal":        { "max_stack": 50, "category": &"resource" },
  &"meat":           { "max_stack": 20, "category": &"consumable" },

  # Tools — tool_slot instead of max_stack
  &"stone_axe":      { "tool_slot": &"axe",     "category": &"tool" },
  &"stone_pickaxe":  { "tool_slot": &"pickaxe",  "category": &"tool" },
  &"survival_knife": { "tool_slot": &"weapon",   "category": &"tool" },
  &"scanner":        { "tool_slot": &"scanner",  "category": &"tool" },
}
```

`category` is informational for UI display. `tool_slot` routes to the correct
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
# [NEW] Includes scan-safety metadata in signal (see use_item flow)
func use_item(type: StringName) -> bool          # false if not in inventory

# Capacity expansion (called when Storage Chest built)
func expand(additional_slots: int) -> void
```

**`add_item` logic:**
1. Check `item_config[type]` — if it has `tool_slot`, reject (tools use `set_tool`)
2. Find existing slot with matching type AND `quantity < max_stack` → fill it
3. If remainder: find first empty slot → create new stack
4. If still remainder: emit `inventory_full`, return amount not added

**Timing: `add_item` is called when the resource ARRIVES, not when gather starts.**
Feature-004's auto-gather runs a tween, then the resource visually "flies to" the
player. `add_item` is called when the flight completes — at the moment the item
would enter inventory. If inventory fills during the flight (another resource arrived
first), the late arrival gets `inventory_full` with proper feedback. No silent loss.

#### Public API — Tool Slots

```gdscript
# Get tool in a slot (returns &"" if empty)
func get_tool(slot: StringName) -> StringName

# Set tool in slot — returns previous tool (for crafting to know what was replaced)
# Previous tool is discarded (gone), not returned to inventory
func set_tool(slot: StringName, tool: StringName) -> StringName

# Convenience — does the player have any tool in this slot?
func has_tool_for(slot: StringName) -> bool
```

**Tool upgrade flow:** `set_tool(&"axe", &"stone_axe")` → returns old (discarded).
One tool per slot, always.

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
      { "type": "", "quantity": 0 }
    ]
  }
}
```

Slots saved in order (position matters for UI). `_base_slots` constant (not saved),
`_bonus_slots` saved, `_max_slots` derived on load.

#### Cross-Feature Data Contracts

| This feature is queried by | Consumer | What it provides |
|---------------------------|----------|-----------------|
| feature-004 (auto-interaction) | `get_tool(slot)` for tool-gating + weapon lookup. `add_item` for gathered resources. | Tool state + item storage |
| feature-006 (crafting) | `has_item`, `remove_item` for recipe ingredients. `set_tool` for crafted tools. | Material queries + tool assignment |
| feature-007 (survival) | `item_used` signal for consumable effects. `remove_item` for death drops. | Consumable trigger + item removal |
| feature-009 (building) | `has_item`, `remove_item` for structure recipes. `expand` for Storage Chest. | Material queries + expansion |
| feature-012 (HUD) | `inventory_changed`, `inventory_full` for UI updates and feedback. | State change signals |

---

### Feature Flow

#### Add Resource (from auto-gather, feature-004)

```
Inventory.add_item(&"wood", 1)
  │
  ├─ item_config[&"wood"] has max_stack → resource path
  ├─ Find existing &"wood" slot with quantity < 99 → increment
  ├─ Else find empty slot → create new stack
  ├─ Else → emit inventory_full(&"wood", 1), return 0
  ├─ Emit item_added(&"wood", 1)
  ├─ Emit inventory_changed()
  └─ Return amount added (1)
```

#### Add Tool (from crafting, feature-006)

```
Inventory.set_tool(&"axe", &"stone_axe")
  │
  ├─ old = _tool_slots[&"axe"]  → &"" or previous tool
  ├─ _tool_slots[&"axe"] = &"stone_axe"
  ├─ Emit tool_changed(&"axe", &"stone_axe", old)
  ├─ Emit inventory_changed()
  └─ Return old (discarded — no salvage)
```

#### Remove Resource (from crafting/building)

```
Inventory.remove_item(&"wood", 5)
  │
  ├─ Scan _slots reverse order — decrement from last partial stacks first
  ├─ Clear empty slots (type = &"", quantity = 0)
  ├─ Emit item_removed(&"wood", 5)
  ├─ Emit inventory_changed()
  └─ Return amount removed
```

Reverse-order consumption minimizes fragmentation.

#### Use Consumable (tap in inventory panel)

```
Player taps berries in inventory panel
  │
  ├─ [NEW] Scan-safety check:
  │     entry_id = RESOURCE_TO_ENTRY[&"berries"]  (from feature-003 mapping)
  │     entry = Catalog.get_entry(entry_id)
  │     if entry.category == FLORA AND entry.properties.toxic:
  │       → Show warning: "This is toxic! Consume anyway? [Yes] [No]"
  │       → If No: return, don't consume
  │       → If Yes: proceed (player's informed choice)
  │     (Non-flora consumables like meat: no warning, always safe)
  │
  ├─ Inventory.use_item(&"berries")
  │     Check has_item(&"berries") → false? return false
  │     remove_item(&"berries", 1)
  │     Emit item_used(&"berries")
  │       → Feature-007 (survival) listens: apply hunger/thirst restore
  │       → If toxic: feature-007 also applies toxic damage
  │     Emit inventory_changed()
  │     Return true
  │
  └─ Done
```

**Ownership split:** Inventory owns the trigger (tap → check → remove → signal).
Feature-007 owns the effect (hunger restore, toxic damage). Inventory doesn't know
about hunger — it emits `item_used`, feature-007 looks up the consumable config.

**[NEW] Toxic flora warning:** The warning is a UI concern owned by `inventory_panel.gd`.
It queries `Catalog.get_entry()` before calling `use_item()`. The Inventory data
layer (`inventory.gd`) does NOT know about toxicity — it just removes and emits.

#### Expand Capacity (Storage Chest built, feature-009)

```
Inventory.expand(12)
  │
  ├─ _bonus_slots += 12
  ├─ Append 12 empty slots to _slots
  ├─ Emit inventory_changed()
  └─ UI renders additional slots
```

Multiple Storage Chests stack. No cap in MVP.

#### Inventory Full — Rejection

When `add_item` can't fit:
- `inventory_full` signal with type and rejected amount
- Auto-gather (feature-004) receives → HUD shows "INVENTORY FULL" floating text
- Resource is NOT dropped on ground (auto-gather simply doesn't produce)

---

### Layers & Components

#### Scene Tree

```
Main (Node)
  └─ World (Node3D)
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ ElementIconRenderer (Node3D)          [feature-003]
       ├─ ScanProgressRenderer (Node3D)         [feature-003]
       ├─ ResourceRenderer (Node3D)             [feature-004]
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)               [feature-002]
       │    ├─ ScannerSystem (Node)             [feature-003]
       │    └─ AutoInteractionSystem (Node)     [feature-004]
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ HUD (CanvasLayer)                          [feature-012]
       ├─ InventoryButton (TextureButton)       ← THIS FEATURE
       └─ InventoryPanel (PanelContainer)       ← THIS FEATURE (bottom drawer)
            ├─ ToolSlotsRow (HBoxContainer)     ← 4 fixed tool slots
            └─ ScrollContainer
                 └─ ResourceGrid (GridContainer) ← 12+ resource slots (3 columns)
```

**No new autoloads.** Inventory is a RefCounted owned by Player, not a singleton.
Other systems access it via Player reference.

#### File Structure

```
scripts/
  inventory/
    inventory.gd            # RefCounted — data + API + signals (owned by Player)

scenes/
  ui/
    inventory_panel.tscn    # PanelContainer — bottom drawer

ui/
  inventory_panel.gd        # Control — open/close, slot rendering, consumable tap + toxic warning
  inventory_slot_ui.gd      # Control — single resource slot (icon, quantity, tap handler)
  tool_slot_ui.gd           # Control — single tool slot (icon, slot label, no tap)

data/
  item_config.tres          # Resource — max_stack, category, tool_slot per item type
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `inventory.gd` | RefCounted owned by Player. All data, API, signals. No scene tree. No UI. Does NOT know about toxicity or catalog. | `item_config.tres` (stack limits, categories) |
| `inventory_panel.gd` | Control on InventoryPanel. Reads `inventory.get_slots()` + tool slots to render. Handles consumable tap with [NEW] toxic warning (queries Catalog). Open/close toggle. `panel_opened` signal for mutual exclusion. | `Inventory` (API + signals), `Catalog` feature-003 (for toxic check on consume) |
| `inventory_slot_ui.gd` | Individual slot Control. Icon + quantity label. Tap: if consumable → delegate to panel (which does toxic check → `use_item`). | `Inventory`, `item_config` |
| `tool_slot_ui.gd` | Tool slot Control. Icon + label (Axe, Pickaxe, Weapon, Scanner). No tap — auto-used. | `Inventory` (get_tool) |

#### Signal Wiring — Complete

```
Inventory signals                        inventory_panel.gd
  inventory_changed()                ──►  re-render all slots + tool slots
  tool_changed(slot, new, old)       ──►  update specific tool slot UI

Inventory signals                        feature-004 (auto-interaction) / feature-012 (HUD)
  inventory_full(type, rejected)     ──►  floating "INVENTORY FULL" text
  item_added(type, amount)           ──►  (feature-004 chain: check for next gather)

Inventory signals                        feature-007 (survival stats)
  item_used(type)                    ──►  apply consumable effect (hunger/thirst/toxic)

inventory_panel.gd
  signal panel_opened()              ──►  other panels close (mutual exclusion)
```

#### Inventory Panel — Open/Close

- **Open:** Tap InventoryButton (HUD bottom-right, 64×64px) → drawer slides up.
  Game continues running — no pause. ~55% of screen shows game world above.
- **Close:** InventoryButton again, X button, or tap game area above panel.
- Panel reads `inventory.get_slots()` + `get_tool()` on open and on `inventory_changed`.
- **Mutual exclusion:** `panel_opened` signal → all other panels close themselves.
  Complete panel list (5 total):
  1. Inventory (this feature, feature-005)
  2. Crafting (feature-006)
  3. Build (feature-009)
  4. Catalog (feature-003)
  5. Journal (feature-011)
  Each panel connects to all others' `panel_opened` signals. Symmetric — no coordinator.

### UI Specs

#### Layout — Portrait 1080×1920

```
┌──────────────────────────┐
│      (game world visible)│  ← ~55% of screen
│                          │
│                          │
├──────────────────────────┤  ← drawer top edge
│  INVENTORY           [X] │  ← header + close
│ [Axe] [Pick] [Wpn] [Scn]│  ← 4 tool slots (fixed row)
│ ─────────────────────────│
│ [1] [2] [3]              │  ← resource grid (3 columns)
│ [4] [5] [6]    scrollable│  ← ScrollContainer always
│ [7] [8] [9]              │
│ [10][11][12]             │  ← ~45% of screen height
└──────────────────────────┘
```

#### Panel Design

- Full-width bottom drawer, ~45% height (~864px at 1920)
- Semi-transparent background
- Header: "INVENTORY" label + close (X) button
- Tool slots: HBoxContainer, 4 slots, labeled (Axe, Pickaxe, Weapon, Scanner)
- Resource grid: ScrollContainer wrapping GridContainer (3 columns).
  Always scrollable from day one.
- Game continues running. No pause.

#### Slot Design

```
┌──────────┐
│  [icon]  │   ← item icon (placeholder: colored square per type)
│    x15   │   ← quantity (bottom-right, hidden if 1 or tool)
└──────────┘
```

- **Size:** ~90×90px. 3 columns = 270px + spacing. Above 48dp.
- **Empty:** faded border, no icon.
- **Consumable:** tap → toxic check (if flora) → `use_item`. Brief highlight animation.
- **[NEW] Toxic consumable:** tap → warning dialog "Toxic! Consume anyway? [Yes/No]".
  If Yes → `use_item`. If No → cancel.
- **Resource (non-consumable):** tap does nothing.
- **Tool slot:** icon + label. No tap.

#### Touch Targets

- Slot: ~90×90px (above 48dp)
- Close: 48×48px
- InventoryButton (HUD): 64×64px
- Spacing: 8-12px between slots
- [NEW] Toxic warning buttons: 120×48px each ("Yes" / "No"), centered in warning dialog

#### Accessibility

- High contrast between slot background and icons
- Quantity text: min 24px
- Empty vs occupied: border style differs (not just color)

---

### Mobile Specs

#### Performance

| Operation | Cost | When |
|-----------|------|------|
| `add_item` | O(n): n = _slots (12-24). Linear scan for partial stack then empty. | On each auto-gather completion |
| `remove_item` | O(n): reverse scan | On craft/build/use |
| `get_slots` | O(n): copy array | On panel open + on inventory_changed |
| `use_item` | O(1): has_item check + remove | On consumable tap |
| `expand` | O(1): append slots | On Storage Chest build |

All operations are O(n) where n ≤ 24 (max expanded slots). Negligible.

#### Draw Calls

Zero 3D draw calls. Inventory is a CanvasLayer UI — all 2D rendering.
HUD buttons are Control nodes. No impact on the 3D draw call budget.

#### Touch Interaction

- InventoryButton tap: opens/closes panel (64×64px target)
- Slot tap: uses consumable (90×90px target, above 48dp)
- All within Godot's `_gui_input` system — no custom touch handling

#### Platform Differences

None. Godot UI Controls work identically on iOS and Android.

#### Memory

- Inventory data: 24 slots × 2 fields = negligible
- 4 tool slots = negligible
- item_config: ~12 entries = negligible
- Panel UI: standard Godot Control nodes
