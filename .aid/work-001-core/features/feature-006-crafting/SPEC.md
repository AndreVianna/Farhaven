# Crafting

## Change Log

| Date | Change | Source |
|------|--------|--------|
| 2026-03-31 | Feature identified from REQUIREMENTS.md §5 F4, §9 AC4 | /aid-interview |
| 2026-03-31 | Full technical specification — all sections | /aid-specify |

## Source

- REQUIREMENTS.md §5 F4 (Crafting)
- REQUIREMENTS.md §9 AC4 (Crafting acceptance criteria)

## Description

Crafting requires a Workbench structure. Recipes are discovered progressively when the player gathers a new material type. Recipes with sufficient materials are selectable; insufficient recipes are greyed out. Crafting consumes materials and produces tools in the player's tool slots. MVP recipes: Stone Axe (2 Wood + 1 Stone), Stone Pickaxe (3 Wood + 2 Stone).

## User Stories

- As a player, I want recipes to appear as I discover materials
- As a player, I want to see which recipes I can afford
- As a player, I want crafting to feel like meaningful progression

## Priority

Must (P0 -- Core Loop)

## Acceptance Criteria

- [ ] Player has 5 Wood + 3 Stone -> Workbench recipe visible in Build menu
- [ ] Player has 2 Wood + 0 Stone -> Workbench recipe greyed out
- [ ] Player gathers Stone for first time -> Stone Axe recipe appears in Craft menu
- [ ] Craft Stone Axe -> materials consumed, tool in axe slot

## Save Integration

Discovered recipes list.

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
Pickaxe (3 Wood + 2 Stone). Creates a meaningful early-game choice — craft Axe first
(speeds up wood auto-gather), then afford the Pickaxe (unlocks ore/crystals).

Both share `discovery_material: &"stone"` — both appear when stone is first gathered.
Cost difference drives the decision, not discovery timing.

`ingredients`: `Dictionary[StringName, int]` — material type → required count.
`output_type`: `&"tool"` for MVP. Future: `&"resource"` for processed materials.
`tool_slot`: which fixed tool slot the output fills (tools only).
`discovery_material`: recipe becomes visible when this material is first gathered.

Lives in `data/recipe_config.tres` or a static Dictionary.

#### Discovered Recipes — Runtime Tracking

```gdscript
var _discovered_recipes: Array[StringName] = []
```

A recipe is "discovered" when the player first gathers the material in
`discovery_material`. Discovery is permanent — never lost even if all of that
material is consumed.

#### Workbench Proximity — Cross-Feature Dependency

Crafting requires a Workbench on an adjacent tile. **This feature does NOT own
Workbench placement** — feature-009 (building) handles that via the Build button.
Crafting performs a read-only proximity check:

```gdscript
func is_near_workbench(player_tile: Vector2i) -> bool:
    for neighbor in HexGrid.get_neighbors(player_tile):
        var tile = HexGrid.get_tile(neighbor)
        if tile and tile.structure == &"workbench":
            return true
    return false
```

No coupling to building internals — reads `HexTile.structure` (feature-001 data).

#### Signals

```gdscript
signal recipe_discovered(recipe_name: StringName)
signal craft_completed(recipe_name: StringName)
signal craft_failed(recipe_name: StringName, reason: StringName)
signal workbench_proximity_changed(near: bool)
```

#### Save Data

```json
{
  "crafting": {
    "discovered_recipes": ["stone_axe", "stone_pickaxe"]
  }
}
```

Only discovered recipes saved. Recipe definitions are static data.

#### Ownership Boundaries

| Concern | Owner |
|---------|-------|
| Workbench placement on map | feature-009 (building) |
| Tool slot assignment (`set_tool`) | feature-005 (inventory) |
| Material storage (`has_item`, `remove_item`) | feature-005 (inventory) |
| Structure recipes (Shelter, Wall, etc.) | feature-009 (building) |
| Recipe definitions + discovery + craft action | **this feature** |

---

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
  │     → HUD (feature-012): brief "New recipe: Stone Axe!" notification
  │
  └─ Done
```

Discovery happens at the moment of pickup (auto-gather → `Inventory.add_item` →
`item_added` signal) — not when opening the crafting panel. Runs once per
`item_added` signal, not per frame.

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

**Validation order matters:** Workbench → already owned → ingredients. Already-owned
check before ingredients so player never sees "insufficient materials" for a recipe
they can't use anyway.

**No craft timer.** Instant — tap recipe, done. Delay is in gathering materials.

**Already-owned is a system block, not just UI.** UI greys out owned tools, but
the craft action enforces it regardless. Never rely on UI alone to prevent bad state.

**Tool upgrade (future):** When metal_axe exists, `get_tool(&"axe")` returns
`&"stone_axe"` (≠ `&"metal_axe"`), so already-owned check passes. Block only
prevents crafting the exact same tool.

#### Crafting Button Visibility

```
On tile_entered / tile_exited (via HexGrid):
  │
  ├─ is_near_workbench(player.current_tile)?
  │
  ├─ YES → show Craft button in HUD
  └─ NO  → hide Craft button
```

Also re-check on `structure_placed` / `structure_destroyed` — player might build
or lose a Workbench while standing nearby.

`crafting_system.gd` emits `workbench_proximity_changed(near: bool)` when state
changes. HUD binds `CraftButton.visible` to this signal.

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
       │    ├─ AutoInteractionSystem (Node)     [feature-004]
       │    └─ CraftingSystem (Node)            ← THIS FEATURE
       └─ Camera3D                              [feature-002]
  └─ JoystickOverlay (CanvasLayer)              [feature-002]
  └─ HUD (CanvasLayer)                          [feature-012]
       ├─ InventoryButton                       [feature-005]
       ├─ CraftButton (TextureButton)           ← THIS FEATURE (visible near Workbench only)
       ├─ InventoryPanel                        [feature-005]
       └─ CraftingPanel (PanelContainer)        ← THIS FEATURE (hidden by default)
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
    crafting_panel.tscn     # PanelContainer — recipe list bottom drawer

ui/
  crafting_panel.gd         # Control — open/close, recipe rendering, craft trigger
  recipe_entry_ui.gd        # Control — single recipe row (name, ingredients, craft button)

data/
  recipe_config.tres        # Resource — recipe definitions
```

#### Component Responsibilities

| Component | Responsibility | Depends On |
|-----------|---------------|------------|
| `crafting_system.gd` | Child Node of Player. Owns `_discovered_recipes`. Recipe discovery (listens to `item_added`). Craft action (validate → consume → produce). Workbench proximity check + `workbench_proximity_changed` signal. `get_save_data()` / `load_save_data()`. | `HexGrid` (tile queries, structure signals), `Inventory` feature-005 (has_item, remove_item, set_tool, item_added signal) |
| `crafting_panel.gd` | Control on CraftingPanel. Renders discovered recipes with ingredient costs. Three states: affordable, unaffordable, already-owned. Calls `crafting_system.craft(recipe_name)`. `panel_opened` signal for mutual exclusion. | `CraftingSystem` (signals), `Inventory` feature-005 (get_count for display, get_tool for owned check) |
| `recipe_entry_ui.gd` | Single recipe row. Icon + name + ingredients (owned/needed, green/red) + Craft button (active/greyed/"Owned"). | `Inventory`, `item_config` |

#### Signal Wiring — Complete

```
Inventory (feature-005) signals              crafting_system.gd
  item_added(type, amount)               ──►  check recipe discovery trigger

HexGrid signals                              crafting_system.gd
  tile_entered(coords)                   ──►  re-check workbench proximity
  tile_exited(coords)                    ──►  re-check workbench proximity
  structure_placed(coords, type)         ──►  re-check (workbench built nearby)
  structure_destroyed(coords, type)      ──►  re-check (workbench destroyed nearby)

crafting_system.gd                           crafting_panel.gd
  recipe_discovered(name)                ──►  add recipe entry to list
  craft_completed(name)                  ──►  refresh affordability display
  craft_failed(name, reason)             ──►  show error feedback

crafting_system.gd                           HUD (feature-012)
  workbench_proximity_changed(near)      ──►  CraftButton.visible = near
  recipe_discovered(name)                ──►  brief "New recipe!" notification
```

#### Panel Mutual Exclusion

Opening CraftingPanel closes all other panels. Complete 5-panel list:
1. Inventory (feature-005)
2. **Crafting (this feature)**
3. Build (feature-009)
4. Catalog (feature-003)
5. Journal (feature-011)

Symmetric `panel_opened` signal pattern — each connects to all others.

#### Crafting Panel — Open/Close

- **Open:** Tap CraftButton (HUD, visible only near Workbench) → slides up.
  Game continues running — no pause. ~55% of screen visible above.
- **Close:** CraftButton again, X button, or tap game area above panel.
- Re-reads recipe data on open + on `inventory_changed` / `craft_completed`.

### UI Specs

#### Layout — Portrait 1080×1920

```
┌──────────────────────────┐
│      (game world visible)│  ← ~55% of screen
│                          │
├──────────────────────────┤
│  CRAFTING            [X] │  ← header + close
│ ─────────────────────────│
│ ┌──────────────────────┐ │
│ │ Stone Axe            │ │
│ │  Wood: 2/2  Stone: 1/1 │ │  ← ingredients (owned/needed)
│ │                [CRAFT]│ │
│ └──────────────────────┘ │
│ ┌──────────────────────┐ │
│ │ Stone Pickaxe        │ │
│ │  Wood: 1/3  Stone: 0/2 │ │  ← greyed (insufficient)
│ │                [----] │ │
│ └──────────────────────┘ │  ← ~45% height, scrollable
└──────────────────────────┘
```

#### Recipe Entry States

| State | Visual | Craft Button |
|-------|--------|-------------|
| Affordable | Full brightness, ingredient counts green | Active — tappable |
| Unaffordable | Dimmed, short ingredients in red | Greyed — not tappable |
| Already owned | Dimmed, "Owned" badge | Greyed — shows "Owned" |

**Ingredient display:** `owned/needed` per material. Green if `owned >= needed`,
red if short. Tells the player what to gather next.

#### Touch Targets

- Recipe entry height: ~100px
- Craft button: ~80×48px
- Close (X): 48×48px
- CraftButton (HUD): 64×64px

#### ScrollContainer

Always present wrapping RecipeList. Ready for future recipe additions.

#### Panel Consistency

- Same bottom-drawer pattern as all panels (full width, ~45% height)
- Same close behavior (X, tap outside, toggle button)
- Semi-transparent background
- Mutual exclusion with all 4 other panels
- Game continues running — no pause

---

### Mobile Specs

#### Performance

| Operation | Cost | When |
|-----------|------|------|
| Recipe discovery check | O(r): r = recipe count (2 in MVP) | On each `item_added` signal |
| Workbench proximity | O(6): check 6 neighbors for structure type | On tile_entered + structure signals |
| Craft validation | O(i): i = ingredients per recipe (2-3) | On craft button tap |
| Craft execution | O(i): remove_item per ingredient + set_tool | On craft button tap |

All O(n) with n ≤ 6. Negligible.

#### Draw Calls

Zero 3D draw calls. CraftingPanel and CraftButton are CanvasLayer UI. No 3D rendering.

#### Touch Interaction

- CraftButton (HUD): 64×64px, visible only near Workbench
- Recipe entries: ~100px height
- Craft button per entry: ~80×48px
- All within Godot's `_gui_input` system

#### Platform Differences

None. Godot UI Controls identical on iOS and Android.

#### Memory

- recipe_config: 2 entries = negligible
- _discovered_recipes: max 2 entries = negligible
- CraftingPanel UI: standard Control nodes
