# Crafting

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-30 | Feature identified from REQUIREMENTS.md §5 F4, §9 AC4 | /aid-interview |
| 2026-03-30 | Data Model written — recipes, discovery, workbench dependency | /aid-specify |
| 2026-03-30 | Feature Flow written — discovery, craft action with already-owned block | /aid-specify |
| 2026-03-30 | Layers & Components written — mutual exclusion for panels | /aid-specify |
| 2026-03-30 | UI Specs written — bottom drawer, recipe entry states, touch targets | /aid-specify |

## Source

- REQUIREMENTS.md §5 F4 (Crafting)
- REQUIREMENTS.md §5 F12 (HUD Layout — crafting button near Workbench)
- REQUIREMENTS.md §9 AC4 (Crafting acceptance criteria)
- REQUIREMENTS.md §10 P0 — Core Loop

## Description

Crafting requires a Workbench structure. Recipes are discovered progressively — when the player picks up a new material type, recipes using that material appear in the crafting UI. Recipes with sufficient materials are selectable; insufficient recipes are greyed out. Crafting consumes materials and produces the item in the player's inventory. MVP recipes include tools (Stone Axe, Stone Pickaxe) and structures (Shelter, Storage Chest, Wall, Torch). A crafting button appears in the HUD when the player is near a Workbench.

## User Stories

- As a player, I want recipes to appear as I discover materials so I'm not overwhelmed at the start
- As a player, I want to see which recipes I can afford so I know what to gather next
- As a player, I want crafting to feel like meaningful progression — new tools unlock new possibilities

## Priority

Must (P0 — Core Loop)

## Acceptance Criteria

- [ ] Player has 5 Wood + 3 Stone → Workbench recipe visible
- [ ] Player has 2 Wood + 0 Stone → Workbench recipe greyed out
- [ ] Player gathers Stone for first time → Stone Axe recipe appears
- [ ] Craft Stone Axe → materials consumed, tool in inventory

## Save Integration

Adds discovered recipes list and equipped tool to save data.

---

## Technical Specification

### Data Model

#### Recipe Definitions — Static Data

Single Dictionary loaded at startup. Keyed by output item name.

```gdscript
# recipe_config: Dictionary[StringName, Dictionary]
{
  &"stone_axe": {
    "ingredients": { &"wood": 2, &"stone": 1 },
    "output_type": &"tool",
    "tool_slot": &"axe",
    "discovery_material": &"stone",
  },
  &"stone_pickaxe": {
    "ingredients": { &"wood": 3, &"stone": 2 },
    "output_type": &"tool",
    "tool_slot": &"pickaxe",
    "discovery_material": &"stone",
  },
}
```

**Ingredient differentiation:** Stone Axe (2 Wood + 1 Stone) is cheaper than Stone
Pickaxe (3 Wood + 2 Stone). This creates a meaningful early-game choice — the player
crafts the Axe first (speeds up wood gathering), then gathers more to afford the
Pickaxe (unlocks ore/crystals in Rocky biome).

Both recipes share `discovery_material: &"stone"` — both appear when the player first
gathers stone. The cost difference drives the decision, not discovery timing.

`ingredients`: `Dictionary[StringName, int]` — material type → required count.
`output_type`: `&"tool"` for MVP. Future: `&"resource"` for processed materials.
`tool_slot`: which fixed tool slot the output fills (tools only).
`discovery_material`: recipe becomes visible when this material is first gathered.

Lives in `data/recipe_config.tres` or a static Dictionary in a constants file.
At 2 recipes, a single file is sufficient. Split into per-recipe `.tres` if count
exceeds ~20 in future work.

#### Discovered Recipes — Runtime Tracking

```gdscript
var _discovered_recipes: Array[StringName] = []
```

A recipe is "discovered" when the player first gathers the material in
`discovery_material`. Discovery is permanent — never lost even if all of that
material is consumed.

#### Workbench Proximity — Cross-Feature Dependency

Crafting requires a Workbench on an adjacent tile. **This feature does NOT own
Workbench placement** — feature-008 (building) handles that via the Build button.
Crafting performs a read-only proximity check:

```gdscript
func is_near_workbench(player_tile: Vector2i) -> bool:
    for neighbor in HexGrid.get_neighbors(player_tile):
        var tile = HexGrid.get_tile(neighbor)
        if tile and tile.structure == &"workbench":
            return true
    return false
```

No coupling to building internals — reads `HexTile.structure` which is part of the
shared HexGrid data model (feature-001).

#### Signals

```gdscript
signal recipe_discovered(recipe_name: StringName)
signal craft_completed(recipe_name: StringName)
signal craft_failed(recipe_name: StringName, reason: StringName)
```

#### Save Data

```json
{
  "crafting": {
    "discovered_recipes": ["stone_axe", "stone_pickaxe"]
  }
}
```

Only discovered recipes are saved. Recipe definitions are static data.

#### Ownership Boundaries

| Concern | Owner |
|---------|-------|
| Workbench placement on map | feature-008 (building) |
| Tool slot assignment (`set_tool`) | feature-004 (inventory) |
| Material storage (`has_item`, `remove_item`) | feature-004 (inventory) |
| Structure recipes (Shelter, Wall, etc.) | feature-008 (building) |
| Recipe definitions + discovery + craft action | **this feature** |

### Feature Flow

#### Recipe Discovery

```
Inventory emits item_added(type, amount)
  │
  ├─ CraftingSystem receives signal
  │
  ├─ For each recipe in recipe_config:
  │     if recipe.discovery_material == type
  │        AND recipe_name not in _discovered_recipes:
  │
  │     → _discovered_recipes.append(recipe_name)
  │     → Emit recipe_discovered(recipe_name)
  │     → UI shows brief "New recipe: Stone Axe!" notification
  │
  └─ Done
```

Discovery happens at the moment of pickup — not when opening the crafting panel.
Check runs once per `item_added` signal, not per frame.

#### Craft Action

```
Player taps a recipe in crafting panel
  │
  ├─ Validate Workbench proximity:
  │     is_near_workbench(player.current_tile)?
  │     ✗ No → craft_failed(name, &"no_workbench"), return
  │       (defensive — panel only opens near Workbench)
  │
  ├─ Validate not already owned (tools):
  │     if recipe.output_type == &"tool":
  │       if Inventory.get_tool(recipe.tool_slot) == recipe_name:
  │         → craft_failed(name, &"already_owned"), return
  │         (system-level block — never consume materials for a duplicate)
  │
  ├─ Validate ingredients:
  │     For each (material, count) in recipe.ingredients:
  │       Inventory.has_item(material, count)?
  │     ✗ Any missing → craft_failed(name, &"insufficient_materials"), return
  │
  ├─ Consume ingredients:
  │     For each (material, count) in recipe.ingredients:
  │       Inventory.remove_item(material, count)
  │
  ├─ Produce output:
  │     if recipe.output_type == &"tool":
  │       old = Inventory.set_tool(recipe.tool_slot, recipe_name)
  │       if old != &"":
  │         → UI shows "Replaced [old] with [new]"
  │
  ├─ Emit craft_completed(recipe_name)
  │     → UI: success feedback (flash, sound hook)
  │     → UI: refresh recipe list (affordability may have changed)
  │
  └─ Done
```

**Validation order matters:** Workbench → already owned → ingredients. The already-owned
check comes before ingredient check so the player never sees "insufficient materials"
for a recipe they can't use anyway.

**No craft timer.** Crafting is instant — tap recipe, done. The delay is in gathering
materials, not in crafting. Keeps the loop snappy.

**Already-owned is a system block, not just UI.** The UI greys out recipes for tools
the player already has (nice UX layer), but the craft action enforces it regardless.
Never rely on UI alone to prevent bad state.

**Tool upgrade (future):** When metal_axe exists, `Inventory.get_tool(&"axe")` returns
`&"stone_axe"` (not `&"metal_axe"`), so the already-owned check passes and the upgrade
proceeds. The block only prevents crafting the exact same tool.

#### Crafting Button Visibility

```
On tile_entered / tile_exited (feature-002 signals via HexGrid):
  │
  ├─ is_near_workbench(player.current_tile)?
  │
  ├─ YES → show Craft button in HUD (bottom-right, next to Inventory + Build)
  └─ NO  → hide Craft button
```

Also re-check on `structure_placed` / `structure_destroyed` — player might build or
lose a Workbench while standing nearby.

### Layers & Components

#### Scene Tree Additions

```
Main (Node)
  └─ World (Node3D)                             [existing]
       ├─ HexGridRenderer (Node3D)              [feature-001]
       ├─ PropRenderer (Node3D)             [feature-003]
       ├─ Player (Node3D)                       [feature-002]
       │    ├─ PlayerVisual (Node3D)
       │    ├─ PlayerInput (Node)
       │    ├─ GatherSystem (Node)              [feature-003]
       │    └─ CraftingSystem (Node)            ← NEW
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ GatherFeedback (CanvasLayer)               [feature-003]
  └─ HUD (CanvasLayer)                          [feature-004]
       ├─ InventoryButton (TextureButton)       [feature-004]
       ├─ CraftButton (TextureButton)           ← NEW (visible only near Workbench)
       ├─ InventoryPanel (PanelContainer)       [feature-004]
       └─ CraftingPanel (PanelContainer)        ← NEW (hidden by default)
            └─ ScrollContainer
                 └─ RecipeList (VBoxContainer)
```

#### File Structure

```
scripts/
  crafting/
    crafting_system.gd      # Node (child of Player) — discovery, craft action,
                             #   workbench proximity, recipe validation

scenes/
  ui/
    crafting_panel.tscn     # PanelContainer — recipe list overlay

ui/
  crafting_panel.gd         # Control — crafting UI logic (open/close, recipe rendering)
  recipe_entry_ui.gd        # Control — single recipe row (name, ingredients, craft button)

data/
  recipe_config.tres        # Resource — recipe definitions
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `crafting_system.gd` | Child Node of Player. Owns `_discovered_recipes`, recipe discovery (listens to `item_added`), craft action (validate → consume → produce), Workbench proximity check, `near_workbench` property. | `HexGrid` (tile queries, structure signals), `Inventory` (has_item, remove_item, set_tool, item_added signal) |
| `crafting_panel.gd` | Control on CraftingPanel. Renders discovered recipes with ingredient costs. Greys out unaffordable and already-owned. Calls `crafting_system.craft()` on tap. | `CraftingSystem` (signals), `Inventory` (queries for display) |
| `recipe_entry_ui.gd` | Single recipe row: name, ingredients with owned/needed counts, Craft button. States: affordable (bright), unaffordable (greyed), already-owned (greyed + "Owned"). | `Inventory` (queries), `item_config` (icons) |

#### Signal Wiring

```
Inventory signals                        crafting_system.gd
  item_added(type, amount)           ──►  check recipe discovery trigger

HexGrid signals                          crafting_system.gd
  tile_entered(coords)               ──►  re-check workbench proximity
  tile_exited(coords)                ──►  re-check workbench proximity
  structure_placed(coords, type)     ──►  re-check (workbench built nearby)
  structure_destroyed(coords, type)  ──►  re-check (workbench destroyed nearby)

crafting_system.gd                       crafting_panel.gd
  recipe_discovered(name)            ──►  add recipe entry to list
  craft_completed(name)              ──►  refresh recipe affordability
  craft_failed(name, reason)         ──►  show error feedback

crafting_system.gd                       HUD
  workbench_proximity_changed(bool)  ──►  CraftButton.visible = near_workbench
```

#### CraftButton Visibility

`crafting_system.gd` emits `workbench_proximity_changed(near: bool)` when proximity
state changes. HUD binds `CraftButton.visible` to this signal. Button only appears
when a Workbench is on an adjacent tile.

#### Panel Mutual Exclusion (system rule)

**Only one panel open at a time.** Opening CraftingPanel closes InventoryPanel, and
vice versa. This is a layout constraint on mobile (1080×1920 portrait) — two
overlapping semi-transparent drawers is visual chaos.

Implementation: both panels emit `panel_opened` signal. Each panel connects to the
other's `panel_opened` and calls `close()` on itself:

```gdscript
# In crafting_panel.gd._ready():
inventory_panel.panel_opened.connect(close)

# In inventory_panel.gd._ready():
crafting_panel.panel_opened.connect(close)
```

This is symmetric — no central coordinator needed. Each panel is responsible for
closing itself when the other opens. The HUD node provides the reference path between
them (both are children of HUD CanvasLayer).

#### Crafting Panel — Open/Close

- **Open:** Tap CraftButton → CraftingPanel slides up (same bottom-drawer pattern as
  InventoryPanel). Closes InventoryPanel if open.
- **Close:** Tap CraftButton again, tap X, or tap game area above.
- Game continues running — no pause.
- Panel re-reads recipe data on open and on `inventory_changed` / `craft_completed`.

### UI Specs

#### Layout — Portrait 1080×1920

```
┌──────────────────────────┐
│  [HP] [Hunger] [Thirst]  │  ← future (feature-006)
│              Day 7 ☀     │  ← future (feature-007)
│                          │
│      (game world visible)│  ← ~55% of screen, game runs
│                          │
│                          │
├──────────────────────────┤  ← drawer top edge
│  CRAFTING            [X] │  ← header + close
│ ─────────────────────────│
│ ┌──────────────────────┐ │
│ │ Stone Axe            │ │  ← recipe entry
│ │  Wood: 2/2  Stone: 1/1 │ │  ← ingredients (owned/needed)
│ │                [CRAFT]│ │  ← craft button
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ Stone Pickaxe        │ │
│ │  Wood: 1/3  Stone: 0/2 │ │  ← greyed out (insufficient)
│ │                [----] │ │
│ └──────────────────────┘ │  ← ~45% of screen height
└──────────────────────────┘
```

#### Recipe Entry Design

Each recipe is a row in VBoxContainer inside ScrollContainer:

```
┌─────────────────────────────────────┐
│  [icon]  Stone Axe                  │
│          Wood: 2/2   Stone: 1/1     │  ← green = owned ≥ needed, red = short
│                          [CRAFT]    │  ← active, greyed, or "Owned"
└─────────────────────────────────────┘
```

#### Recipe Entry States

| State | Visual | Craft Button |
|-------|--------|-------------|
| Affordable | Full brightness, ingredient counts green | Active — tappable |
| Unaffordable | Dimmed, short ingredients in red | Greyed — not tappable |
| Already owned | Dimmed, "Owned" badge | Greyed — shows "Owned" |

**Ingredient display:** Each ingredient shows `owned/needed` count. Owned from
`Inventory.get_count(type)`. Green if `owned >= needed`, red if short. Tells the
player exactly what to gather next.

#### Touch Targets

- Recipe entry height: ~100px (comfortable tap on mobile)
- Craft button within entry: ~80×48px minimum
- Close button (X): 48×48px
- CraftButton (HUD): 64×64px, same size as InventoryButton

#### ScrollContainer

Always present wrapping RecipeList. At 2 recipes the content fits without scrolling,
but the container is ready for future recipe additions without layout rework.

#### Consistency with InventoryPanel

- Same bottom-drawer pattern (full width, ~45% height)
- Same close behavior (X, tap outside, toggle button)
- Same semi-transparent background
- Mutual exclusion enforced (opening one closes the other)
- Game continues running — no pause
